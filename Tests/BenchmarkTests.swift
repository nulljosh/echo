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

    func testBenchmarkEveryEngine() async throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipIf(env["VOXPRINT_BENCH"] == nil, "opt-in benchmark")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-bench.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEF32@16000", Self.script]
        try say.run(); say.waitUntilExit()
        let file = try AVAudioFile(forReading: wav)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        let samples = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))
        let seconds = Double(samples.count) / 16_000

        var rows: [String] = []
        func row(_ name: String, load: Double, run: Double, text: String) {
            let wer = Self.wordErrorRate(text, Self.script)
            rows.append(String(format: "| %@ | %.1f s | %.2f s | %.0fx | %.0f%% |", name, load, run, seconds / run, wer * 100))
        }

        for model in ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small_216MB"] {
            guard let folder = TranscriptionEngine.bundled(model) else { continue }
            let loadStart = Date()
            let kit = try await TranscriptionEngine.loadBundled(folder)
            let load = Date().timeIntervalSince(loadStart)
            _ = try await kit.transcribe(audioArray: Array(samples.prefix(16_000))) // warm up
            var best = Double.infinity, text = ""
            for _ in 0..<2 {
                let start = Date()
                let results = try await kit.transcribe(audioArray: samples)
                best = min(best, Date().timeIntervalSince(start))
                text = results.map(\.text).joined(separator: " ")
            }
            row(model.replacingOccurrences(of: "openai_whisper-", with: "Whisper ").replacingOccurrences(of: "_216MB", with: ""), load: load, run: best, text: text)
        }

        if #available(macOS 26.0, *) {
            await AppleSpeech.prepare(for: "en")
            if let locale = await AppleSpeech.installedLocale(for: "en") {
                var best = Double.infinity, text = ""
                for _ in 0..<2 {
                    let start = Date()
                    let lines = try await AppleSpeech.transcribe(url: wav, locale: locale)
                    best = min(best, Date().timeIntervalSince(start))
                    text = lines.map(\.text).joined(separator: " ")
                }
                row("Apple SpeechAnalyzer", load: 0, run: best, text: text)
            }
        }

        let host = ProcessInfo.processInfo
        let report = """
        | Engine | Load | Transcribe | Faster than real time | Word error rate |
        |---|---|---|---|---|
        \(rows.joined(separator: "\n"))

        Clip: \(String(format: "%.1f", seconds)) s of `say` speech, 16 kHz. Best of two runs after a warm-up. \(host.processorCount) cores, \(host.physicalMemory / 1_073_741_824) GB, macOS \(host.operatingSystemVersionString).
        """
        print(report)
        if let out = env["VOXPRINT_BENCH_OUT"] { try report.write(toFile: out, atomically: true, encoding: .utf8) }
        XCTAssertFalse(rows.isEmpty, "no engine ran")
    }
}
