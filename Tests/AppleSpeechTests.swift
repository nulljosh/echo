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
        try await live.start { _ in updates += 1 }
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
}
