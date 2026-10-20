import XCTest
import AVFoundation
import WhisperKit
@testable import Voxprint_macOS

/// Benchmarks every engine Echo ships on one clip: load time, speed against real time, and word error rate.
/// Opt-in, and slow on a cold Neural Engine. Writes a markdown table to $VOXPRINT_BENCH_OUT:
///   TEST_RUNNER_VOXPRINT_BENCH=1 TEST_RUNNER_VOXPRINT_BENCH_OUT=/tmp/bench.md xcodebuild test -scheme VoxprintTests \
///     -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:VoxprintTests/BenchmarkTests
@MainActor
final class BenchmarkTests: XCTestCase {
    static let script = "Echo turns speech into text on your own device. Nothing is uploaded, so it works on a plane, in a basement, or anywhere without a signal. Say a name once in custom words and it gets spelled your way. When you stop, the whole recording is read once more for the final text."

    /// Word error rate: word-level edit distance over the reference length, case and punctuation ignored.
    static func wordErrorRate(_ hypothesis: String, _ reference: String) -> Double {
        func words(_ s: String) -> [Substring] {
            s.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }
        }
        let h = words(hypothesis), r = words(reference)
        guard !r.isEmpty else { return h.isEmpty ? 0 : 1 }
        var row = Array(0...h.count)
        for i in 1...r.count {
            var previous = row[0]
            row[0] = i
            for j in stride(from: 1, through: h.count, by: 1) {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (r[i - 1] == h[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return Double(row[h.count]) / Double(r.count)
    }

    func testWordErrorRate() {
        XCTAssertEqual(Self.wordErrorRate("the cat sat", "The cat sat."), 0)
        XCTAssertEqual(Self.wordErrorRate("the cat", "the cat sat"), 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(Self.wordErrorRate("a dog sat down", "the cat sat"), 1.0, accuracy: 1e-9)
    }

    static let gettysburg = "Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal. Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure. We are met on a great battlefield of that war. We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live. It is altogether fitting and proper that we should do this. But, in a larger sense, we cannot dedicate, we cannot consecrate, we cannot hallow this ground. The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. The world will little note, nor long remember what we say here, but it can never forget what they did here. It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced. It is rather for us to be here dedicated to the great task remaining before us, that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion, that we here highly resolve that these dead shall not have died in vain, that this nation, under God, shall have a new birth of freedom, and that government of the people, by the people, for the people, shall not perish from the earth."

    /// Keeps only the speech itself: LibriVox readings open and close with a credit that is not in the text.
    /// The speech starts after the last sentence before "score and seven", since engines spell the first word
    /// "Four", "For" or "Fourscore".
    static func trimToSpeech(_ text: String) -> String {
        let lower = text.lowercased()
        var start = lower.startIndex
        if let anchor = lower.range(of: "score and seven")?.lowerBound, let dot = lower[..<anchor].lastIndex(of: ".") {
            start = lower.index(after: dot)
        }
        let end = lower.range(of: "from the earth", options: .backwards)?.upperBound ?? lower.endIndex
        return start < end ? String(text[start..<end]) : text
    }

    /// 16 kHz mono samples from any audio file AVFoundation reads.
    static func samples16k(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: input)
        let converter = AVAudioConverter(from: file.processingFormat, to: target)!
        let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(Double(file.length) * 16_000 / file.processingFormat.sampleRate) + 1024)!
        var given = false
        _ = converter.convert(to: out, error: nil) { _, status in
            if given { status.pointee = .endOfStream; return nil }
            given = true; status.pointee = .haveData; return input
        }
        return Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
    }

    func testTrimToSpeech() {
        XCTAssertEqual(Self.trimToSpeech("Recording by Jim. For score and seven years, from the earth. End of recording"), " For score and seven years, from the earth")
        XCTAssertEqual(Self.trimToSpeech("Fourscore and seven years ago"), "Fourscore and seven years ago")
    }

    func testBenchmarkEveryEngine() async throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipIf(env["VOXPRINT_BENCH"] == nil, "opt-in benchmark")
        let tmp = FileManager.default.temporaryDirectory
        let wav = tmp.appendingPathComponent("echo-bench.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEF32@16000", Self.script]
        try say.run(); say.waitUntilExit()
        // A real voice: a public domain LibriVox reading of the Gettysburg Address, fetched once.
        let human = tmp.appendingPathComponent("echo-bench-gettysburg.mp3")
        if !FileManager.default.fileExists(atPath: human.path) {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://archive.org/download/gettysburg_address4_librivox/lincoln_gettysburg_address_64kb.mp3")!)
            try data.write(to: human)
        }
        let clips: [(name: String, url: URL, reference: String, trim: Bool)] = [
            ("`say` voice", wav, Self.script, false),
            ("Human, LibriVox", human, Self.gettysburg, true),
        ]

        var rows: [String] = []
        var kits: [(String, WhisperKit, Double)] = []
        for model in ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small_216MB"] {
            guard let folder = TranscriptionEngine.bundled(model) else { continue }
            let loadStart = Date()
            let kit = try await TranscriptionEngine.loadBundled(folder)
            kits.append((model.replacingOccurrences(of: "openai_whisper-", with: "Whisper ").replacingOccurrences(of: "_216MB", with: ""), kit, Date().timeIntervalSince(loadStart)))
        }
        var appleLocale: Locale?
        if #available(macOS 26.0, *) {
            await AppleSpeech.prepare(for: "en")
            appleLocale = await AppleSpeech.installedLocale(for: "en")
        }

        for clip in clips {
            let samples = try Self.samples16k(clip.url)
            let seconds = Double(samples.count) / 16_000
            func row(_ name: String, load: Double, run: Double, text: String) {
                let heard = clip.trim ? Self.trimToSpeech(text) : text
                let wer = Self.wordErrorRate(heard, clip.reference)
                print("HEARD \(name), \(clip.name): \(heard)")
                rows.append(String(format: "| %@ | %@ (%.0f s) | %.1f s | %.2f s | %.0fx | %.1f%% |", name, clip.name, seconds, load, run, seconds / run, wer * 100))
            }
            for (name, kit, load) in kits {
                _ = try await kit.transcribe(audioArray: Array(samples.prefix(16_000))) // warm up
                var best = Double.infinity, text = ""
                for _ in 0..<2 {
                    let start = Date()
                    let results = try await kit.transcribe(audioArray: samples)
                    best = min(best, Date().timeIntervalSince(start))
                    text = results.map(\.text).joined(separator: " ")
                }
                row(name, load: load, run: best, text: text)
            }
            if #available(macOS 26.0, *), let locale = appleLocale {
                var best = Double.infinity, text = ""
                for _ in 0..<2 {
                    let start = Date()
                    let lines = try await AppleSpeech.transcribe(url: clip.url, locale: locale)
                    best = min(best, Date().timeIntervalSince(start))
                    text = lines.map(\.text).joined(separator: " ")
                }
                row("Apple SpeechAnalyzer", load: 0, run: best, text: text)
            }
        }

        let host = ProcessInfo.processInfo
        let report = """
        | Engine | Clip | Load | Transcribe | Faster than real time | Word error rate |
        |---|---|---|---|---|---|
        \(rows.joined(separator: "\n"))

        Best of two runs after a warm-up. Word error rate ignores case and punctuation; the LibriVox credit is trimmed off. \(host.processorCount) cores, \(host.physicalMemory / 1_073_741_824) GB, macOS \(host.operatingSystemVersionString).
        """
        print(report)
        if let out = env["VOXPRINT_BENCH_OUT"] { try report.write(toFile: out, atomically: true, encoding: .utf8) }
        XCTAssertFalse(rows.isEmpty, "no engine ran")
    }
}
