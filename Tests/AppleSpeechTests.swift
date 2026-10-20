import XCTest
import AVFoundation
@testable import Voxprint_macOS

/// Apple first: SpeechAnalyzer on macOS 26. Opt-in like the rest of the QA run.
@MainActor
final class AppleSpeechTests: XCTestCase {
    /// Apple first: SpeechAnalyzer's live session hears real speech, keeps the start of a long recording and the end.
    func testAppleLiveTranscribesRealSpeech() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        guard #available(macOS 26.0, *) else { throw XCTSkip("SpeechAnalyzer needs macOS 26") }
        await AppleSpeech.prepare(for: "en")
        let locale = await AppleSpeech.installedLocale(for: "en")
        try XCTSkipIf(locale == nil, "Apple's English model did not install")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-apple.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEF32@16000", "-r", "150",
            "This recording starts with a banana. " + String(repeating: "We keep talking so the live session has to hold every sentence. ", count: 5) + "It ends with a pineapple."]
        try say.run(); say.waitUntilExit()
        let file = try AVAudioFile(forReading: wav)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        let samples = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))

        let session = await AppleSpeech.Live(locale: locale!)
        let live = try XCTUnwrap(session)
        var updates = 0
        try await live.start { _, _ in updates += 1 }
        for start in stride(from: 0, to: samples.count, by: 3_200) { // 200 ms chunks, like the recorder
            live.feed(Array(samples[start..<min(start + 3_200, samples.count)]))
        }
        await live.finish()
        let text = live.finalText.lowercased()
        XCTAssertTrue(text.contains("recording"), "start dropped: \(text)")
        XCTAssertTrue(text.contains("pineapple"), "end missing: \(text)")
        XCTAssertFalse(live.lines.isEmpty, "no timed lines for SRT")
        XCTAssertGreaterThan(updates, 0, "no live updates")
    }

    /// Apple's speech model transcribes a file with timings, when it is installed for English on this machine.
    @MainActor
    func testAppleSpeechFile() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        let locale = await AppleSpeech.installedLocale(for: "en")
        try XCTSkipIf(locale == nil, "Apple's English model is not installed here")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-apple.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEI16@16000", "The quick brown fox jumps over the lazy dog near the river bank."]
        try say.run(); say.waitUntilExit()
        let engine = TranscriptionEngine()
        engine.selectedModel = AppleSpeech.modelID
        engine.selectedLanguage = "en"
        await engine.transcribeFile(url: wav)
        let heard = engine.transcribedText.lowercased()
        for word in ["quick", "fox", "lazy", "river"] { XCTAssertTrue(heard.contains(word), "Apple missed \"\(word)\": \(heard)") }
        let entry = try XCTUnwrap(engine.entries.first)
        XCTAssertEqual(entry.model, AppleSpeech.modelID)
        XCTAssertFalse(entry.lines?.isEmpty ?? true, "timed lines for subtitles")
        engine.deleteEntry(entry)
    }

    /// The rule for when Apple runs. Pure, so it never touches the real app's saved custom words.
    func testAppleFitsOnlyWhenItCan() {
        XCTAssertTrue(TranscriptionEngine.appleFits(model: "auto", customWords: ""))
        XCTAssertTrue(TranscriptionEngine.appleFits(model: AppleSpeech.modelID, customWords: "  "))
        XCTAssertFalse(TranscriptionEngine.appleFits(model: "auto", customWords: "Jaybulb"), "custom words need Whisper's prompt")
        XCTAssertFalse(TranscriptionEngine.appleFits(model: "openai_whisper-tiny", customWords: ""))
    }

    /// The engine's own Apple path: start, pump, finish. Then stop pressed while the session is still starting.
    func testEngineRecordsThroughAppleAndStopsCleanly() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        guard #available(macOS 26.0, *) else { throw XCTSkip("SpeechAnalyzer needs macOS 26") }
        await AppleSpeech.prepare(for: Locale.current.language.languageCode?.identifier ?? "en")
        let installed = await AppleSpeech.installedLocale(for: "auto")
        try XCTSkipIf(installed == nil, "Apple's model for this Mac's language is not installed")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-engine-apple.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEF32@16000", "Please remember to water the pineapple."]
        try say.run(); say.waitUntilExit()
        let file = try AVAudioFile(forReading: wav)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        let samples = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))

        let engine = TranscriptionEngine()
        engine.selectedModel = "auto"
        try XCTSkipIf(!TranscriptionEngine.appleFits(model: "auto", customWords: engine.customWords), "this Mac has custom words saved, so Whisper runs")
        let used = await engine.simulateAppleLive(samples)
        XCTAssertTrue(used, "Auto should record through Apple here")
        XCTAssertTrue(engine.transcribedText.lowercased().contains("pineapple"), "lost the end: \(engine.transcribedText)")
        XCTAssertFalse(engine.finalLines.isEmpty, "no timed lines")

        // Stop the instant recording starts: it must finish, and anything Apple heard must be complete.
        let early = await engine.simulateAppleLive(samples, listen: .zero)
        if early { XCTAssertTrue(engine.transcribedText.lowercased().contains("pineapple"), "early stop lost words: \(engine.transcribedText)") }
    }

    /// Meetings on Apple: the mixed mic and call audio through SpeechAnalyzer, each line labelled You or Them.
    func testAppleMeetingSpeakerLabels() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        guard #available(macOS 26.0, *) else { throw XCTSkip("SpeechAnalyzer needs macOS 26") }
        await AppleSpeech.prepare(for: Locale.current.language.languageCode?.identifier ?? "en")
        let installed = await AppleSpeech.installedLocale(for: "auto")
        try XCTSkipIf(installed == nil, "Apple's model for this Mac's language is not installed")
        func speech(_ text: String, voice: String) throws -> [Float] {
            let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-apple-\(voice).wav")
            let say = Process()
            say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            say.arguments = ["-v", voice, "-o", wav.path, "--data-format=LEF32@16000", text]
            try say.run(); say.waitUntilExit()
            let file = try AVAudioFile(forReading: wav)
            let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buf)
            return Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))
        }
        let mine = try speech("Can you send me the quarterly budget by Friday.", voice: "Samantha")
        let theirs = try speech("Sure, I will email the budget tomorrow morning.", voice: "Daniel")
        let gap = [Float](repeating: 0, count: 32_000)
        let mic = mine + gap + [Float](repeating: 0, count: theirs.count)
        let call = [Float](repeating: 0, count: mine.count) + gap + theirs
        var mixer = AudioMixer(), mixed: [Float] = []
        for i in stride(from: 0, to: mic.count, by: 32_000) { // 2 s at a time, as the two captures arrive
            mixed += mixer.pushMic(Array(mic[i..<min(mic.count, i + 32_000)]))
            mixed += mixer.pushSystem(Array(call[i..<min(call.count, i + 32_000)]))
        }

        let engine = TranscriptionEngine()
        engine.selectedModel = "auto"
        try XCTSkipIf(!TranscriptionEngine.appleFits(model: "auto", customWords: engine.customWords), "this Mac has custom words saved, so Whisper runs")
        engine.bufferLock.withLock { engine.speakerFrames = mixer.takeFrames() }
        let used = await engine.simulateAppleLive(mixed)
        XCTAssertTrue(used, "Auto should record the meeting through Apple here")
        let text = engine.transcribedText
        let lines = text.split(separator: "\n").map { $0.lowercased() }
        XCTAssertTrue(lines.contains { $0.hasPrefix("you:") && $0.contains("friday") }, "mic line not labelled You: \(text)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("them:") && $0.contains("tomorrow") }, "call line not labelled Them: \(text)")
        XCTAssertEqual(Set(engine.finalLines.compactMap(\.speaker)), ["You", "Them"])
    }
}
