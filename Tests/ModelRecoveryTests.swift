import XCTest
import AppIntents
import SwiftUI
import AVFoundation
@testable import Voxprint_macOS

/// End-to-end QA: a corrupt model folder must heal itself, then real speech must transcribe.
/// Needs network (downloads the tiny model), so it is opt-in:
///   TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO
@MainActor
final class ModelRecoveryTests: XCTestCase {
    func testCorruptModelHealsThenTranscribes() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in, needs network")
        let fm = FileManager.default
        let model = "openai_whisper-tiny"
        let stable = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("echo-models").appendingPathComponent(model)

        // The 1.3.9 brick: a half-copied model sitting at the stable path.
        try? fm.removeItem(at: stable)
        let junk = stable.appendingPathComponent("MelSpectrogram.mlmodelc")
        try fm.createDirectory(at: junk, withIntermediateDirectories: true)
        try Data("not a model".utf8).write(to: junk.appendingPathComponent("model.mil"))

        let engine = TranscriptionEngine()
        engine.selectedModel = model
        await engine.loadModel()
        XCTAssertEqual(engine.modelState, .ready, "engine should wipe the corrupt copy and recover")

        // Second engine = next launch. Must load from the healed stable copy.
        let relaunch = TranscriptionEngine()
        relaunch.selectedModel = model
        await relaunch.loadModel()
        XCTAssertEqual(relaunch.modelState, .ready)

        let wav = fm.temporaryDirectory.appendingPathComponent("voxprint-qa.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEI16@16000", "Hello, this is a transcription test for the quality check."]
        try say.run()
        say.waitUntilExit()

        await relaunch.transcribeFile(url: wav)
        let text = relaunch.transcribedText.lowercased()
        XCTAssertTrue(text.contains("transcription"), "got: \(text)")
        XCTAssertEqual(relaunch.entries.first?.text.lowercased(), text, "history should record it")
        if let entry = relaunch.entries.first { relaunch.deleteEntry(entry) } // keep real history clean
    }

    /// 1.4.2: a broken copy of the chosen model must drop back to the bundled tiny model at once,
    /// not an error screen, and the broken copy must be gone so the next launch can re-fetch it.
    func testBrokenChosenModelFallsBackToBundledTiny() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        try XCTSkipIf(TranscriptionEngine.bundledTiny == nil, "tiny model not bundled (run scripts/fetch-tiny-model.sh)")
        let fm = FileManager.default
        let model = "openai_whisper-large-v3-v20240930_turbo_632MB" // not bundled, so it can be broken and re-fetched
        let stable = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("echo-models").appendingPathComponent(model)
        try? fm.removeItem(at: stable)
        let junk = stable.appendingPathComponent("AudioEncoder.mlmodelc")
        try fm.createDirectory(at: junk, withIntermediateDirectories: true)
        try Data("not a model".utf8).write(to: junk.appendingPathComponent("model.mil"))

        TranscriptionEngine.downloadsEnabled = false
        defer { TranscriptionEngine.downloadsEnabled = true }
        let engine = TranscriptionEngine()
        engine.selectedModel = model
        await engine.loadModel()
        await engine.waitForUpgrade() // tries the broken copy, drops it, and stops short of a download
        XCTAssertEqual(engine.modelState, .ready, "broken model must not leave an error screen")
        XCTAssertEqual(engine.activeModel, TranscriptionEngine.tinyModel, "should be running on the bundled tiny model")
        XCTAssertFalse(fm.fileExists(atPath: stable.path), "the broken copy must be deleted")
    }

    /// 1.4.2: open it and it works. Tiny is ready in seconds from the bundle, then the model auto picks
    /// (also bundled) swaps in from the bundle. Nothing downloads at any point.
    func testOpensReadyAndSwapsToBundledModelWithoutDownload() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        for m in ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small_216MB"] {
            XCTAssertNotNil(TranscriptionEngine.bundled(m), "\(m) must ship inside the app (run scripts/fetch-tiny-model.sh)")
        }
        TranscriptionEngine.downloadsEnabled = false // any download attempt would leave the chosen model unloaded
        defer { TranscriptionEngine.downloadsEnabled = true }
        let engine = TranscriptionEngine()
        engine.selectedModel = "auto"
        let start = Date()
        await engine.loadModel()
        XCTAssertEqual(engine.modelState, .ready)
        XCTAssertLessThan(Date().timeIntervalSince(start), 20, "first launch must be ready in seconds, got \(Date().timeIntervalSince(start))s")
        XCTAssertNil(engine.upgradeProgress, "nothing may download")
        await engine.waitForUpgrade()
        XCTAssertEqual(engine.activeModel, engine.resolvedModel, "the chosen bundled model must swap in")
        // The swapped-in model (the quantized small on a Mac) must still hear real speech right.
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-accuracy.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEI16@16000", "The quick brown fox jumps over the lazy dog near the river bank."]
        try say.run(); say.waitUntilExit()
        await engine.transcribeFile(url: wav)
        let heard = engine.transcribedText.lowercased()
        for word in ["quick", "brown", "fox", "lazy", "river"] { XCTAssertTrue(heard.contains(word), "\(engine.activeModel) missed \"\(word)\": \(heard)") }
        if let entry = engine.entries.first { engine.deleteEntry(entry) }
        for m in ["openai_whisper-tiny", "openai_whisper-small_216MB"] {
            let folder = TranscriptionEngine.bundled(m)!
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("tokenizer.json").path), "\(m) must carry its tokenizer")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("models").path), "the tokenizer was fetched from the internet")
        }
    }

    /// Live transcript keeps everything said, not just the last few seconds: 40 s of speech through the live path.
    func testLiveTranscriptKeepsEverythingSaid() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-long.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEF32@16000", "-r", "150",
            "Banana is the first word of this long recording. " + String(repeating: "We are talking for a while so the live transcript has to keep up with every sentence. ", count: 7) + "Finally the last word is pineapple."]
        try say.run(); say.waitUntilExit()
        let file = try AVAudioFile(forReading: wav)
        let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buf)
        let samples = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength)))
        XCTAssertGreaterThan(samples.count, 16_000 * 30, "need more than the 30 s window")

        // The model people actually get: tiny first, then the bundled model auto picks swaps in.
        let engine = TranscriptionEngine()
        engine.selectedModel = "auto"
        await engine.loadModel()
        await engine.waitForUpgrade()
        await engine.simulateLive(samples)
        let text = engine.transcribedText.lowercased()
        // "recording" is only in the opening sentence (a single word like "banana" is at the mercy of tiny's ear)
        XCTAssertTrue(text.contains("recording"), "first sentence dropped from the live transcript: \(text)")
        XCTAssertTrue(text.contains("pineapple"), "last words missing: \(text)")
        XCTAssertFalse(text.contains("<|"), "timestamp tokens leaked: \(text)")
    }

    /// Meeting mixer: lines up mic and call audio, sums them, and never lets a stalled stream hold the other back.
    func testMeetingMixer() {
        var m = AudioMixer()
        XCTAssertTrue(m.pushMic([0.25, 0.25]).isEmpty, "waits for the call stream")
        XCTAssertEqual(m.pushSystem([0.5, 0.5, 0.5]), [0.75, 0.75], "sums aligned samples")
        XCTAssertEqual(m.pushMic([0.9]), [1.0], "clamps to 1")
        // the call goes silent and stops sending: the mic must keep flowing after half a second
        let out = m.pushMic([Float](repeating: 0.1, count: AudioMixer.maxLag + 1))
        XCTAssertEqual(out.count, AudioMixer.maxLag + 1)
    }

    /// Meeting mode labels who spoke: the mic voice is You, the call voice is Them.
    func testMeetingSpeakerLabels() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        func speech(_ text: String, voice: String) throws -> [Float] {
            let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-\(voice).wav")
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
        let gap = [Float](repeating: 0, count: 16_000)
        let mic = mine + gap + [Float](repeating: 0, count: theirs.count)
        let call = [Float](repeating: 0, count: mine.count) + gap + theirs

        let engine = TranscriptionEngine()
        engine.selectedModel = "auto"
        await engine.loadModel()
        await engine.waitForUpgrade()
        await engine.simulateMeeting(mic: mic, call: call)
        let text = engine.transcribedText
        let lines = text.split(separator: "\n").map { $0.lowercased() }
        XCTAssertTrue(lines.contains { $0.hasPrefix("you:") && $0.contains("budget") && $0.contains("friday") }, "mic line not labelled You: \(text)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("them:") && $0.contains("tomorrow") }, "call line not labelled Them: \(text)")
    }

    /// Custom words: clean prompt text, and a prompt must never blank real speech.
    func testCustomWordsPromptTextAndNoBlankOutput() async throws {
        XCTAssertNil(TranscriptionEngine.promptText(from: " , \n "))
        XCTAssertEqual(TranscriptionEngine.promptText(from: "Echo, LEC\necho, Jaybulb"), " Echo, LEC, Jaybulb.")
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        try XCTSkipIf(TranscriptionEngine.bundledTiny == nil, "tiny model not bundled")
        let engine = TranscriptionEngine()
        engine.selectedModel = TranscriptionEngine.tinyModel
        let saved = engine.customWords
        engine.customWords = "Echo, Jaybulb, Healstack, LEC"
        defer { engine.customWords = saved }
        await engine.loadModel()
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-words.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEI16@16000", "Hello, this is a transcription test for the quality check."]
        try say.run(); say.waitUntilExit()
        await engine.transcribeFile(url: wav)
        XCTAssertTrue(engine.transcribedText.lowercased().contains("transcription"), "prompt must not blank the output, got: \(engine.transcribedText)")
        if let entry = engine.entries.first { engine.deleteEntry(entry) }
    }

    /// Cleanup never loses words: without the system model it returns the text untouched.
    func testCleanupKeepsTextWhenModelMissing() async throws {
        try XCTSkipIf(Cleanup.isAvailable, "system model present; covered by the live check")
        let text = "um so this is a test you know"
        let out = try await Cleanup.clean(text)
        XCTAssertEqual(out, text)
    }

    /// Live: on a Mac with Apple Intelligence, cleanup keeps the words and drops the filler.
    func testCleanupLive() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        try XCTSkipUnless(Cleanup.isAvailable, "no system model on this machine")
        let out = try await Cleanup.clean("um so this is uh a test of the cleanup you know")
        XCTAssertTrue(out.lowercased().contains("test"), "lost the words: \(out)")
        XCTAssertFalse(out.lowercased().contains(" uh "), "filler kept: \(out)")
    }

    /// Live: summary keeps to what was said and finds the task someone agreed to.
    func testSummaryLive() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        try XCTSkipUnless(Cleanup.isAvailable, "no system model on this machine")
        let transcript = "You: Can you send me the quarterly budget by Friday?\nThem: Sure, I will email the budget tomorrow morning. Also the office is closed on Monday."
        let result = try await Summarizer.summarize(transcript)
        let s = try XCTUnwrap(result)
        XCTAssertFalse(s.summary.isEmpty)
        XCTAssertTrue(s.actionItems.contains { $0.lowercased().contains("budget") }, "missed the task: \(s.actionItems)")
    }

    /// The summary sheet renders; the PNG lands in the temp folder for a look.
    @MainActor
    func testSummaryViewRenders() throws {
        let view = SummaryView(summary: TranscriptSummary(summary: "You asked for the quarterly budget by Friday. They will email it tomorrow morning, and the office is closed Monday.", actionItems: ["Them: email the quarterly budget tomorrow morning", "You: check the budget before Friday"]))
            .frame(width: 480).background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "summary sheet did not render")
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try rep.representation(using: .png, properties: [:])!.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("echo-summary.png"))
    }

    /// History search: every word must match, any case or accent, transcript or summary.
    func testHistorySearch() {
        var e = TranscriptionEntry(text: "Meeting about the Café opening on Friday", duration: 9, model: "tiny")
        XCTAssertTrue(HistoryView.matches(e, ""))
        XCTAssertTrue(HistoryView.matches(e, "cafe friday"))
        XCTAssertFalse(HistoryView.matches(e, "cafe monday"))
        e.summary = TranscriptSummary(summary: "Plans", actionItems: ["Order the espresso machine"])
        XCTAssertTrue(HistoryView.matches(e, "espresso"))
    }

    /// Export: Markdown bolds speakers and lists action items, SRT has numbered timed cues.
    func testExportFormats() {
        var e = TranscriptionEntry(text: "You: send the budget\nThem: tomorrow morning", duration: 6, model: "tiny")
        e.summary = TranscriptSummary(summary: "Budget talk.", actionItems: ["Them: email the budget"])
        e.lines = [TimedLine(start: 0, end: 2.5, text: "send the budget", speaker: "You"),
                   TimedLine(start: 3, end: 61.25, text: "tomorrow morning", speaker: "Them")]
        let md = Exporter.markdown(e)
        XCTAssertTrue(md.contains("**You:** send the budget"))
        XCTAssertTrue(md.contains("- [ ] Them: email the budget"))
        let srt = Exporter.srt(e)
        XCTAssertTrue(srt.hasPrefix("1\n00:00:00,000 --> 00:00:02,500\nYou: send the budget"), srt)
        XCTAssertTrue(srt.contains("2\n00:00:03,000 --> 00:01:01,250\nThem: tomorrow morning"), srt)
        XCTAssertEqual(Exporter.stamp(3725.5), "01:02:05,500")
    }

    /// Shortcuts: "Transcribe Audio" hands back the words; "Start Recording" is never lost if the UI isn't up yet.
    @MainActor
    func testShortcutIntents() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["VOXPRINT_QA"] == nil, "opt-in")
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("echo-intent.wav")
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-o", wav.path, "--data-format=LEI16@16000", "Remember to water the plants on Sunday."]
        try say.run(); say.waitUntilExit()
        var intent = TranscribeAudioIntent()
        intent.audio = IntentFile(data: try Data(contentsOf: wav), filename: "memo.wav")
        let result = try await intent.perform()
        let text = (result.value ?? "").lowercased()
        XCTAssertTrue(text.contains("plants") && text.contains("sunday"), "got: \(text)")
        // history entry from the intent stays out of the real history
        let engine = TranscriptionEngine()
        if let e = engine.entries.first(where: { $0.text.lowercased() == text }) { engine.deleteEntry(e) }

        // The pending flag, without posting to the running test host (that would start a real recording).
        IntentInbox.pendingStart = true
        XCTAssertTrue(IntentInbox.takePendingStart(), "start request must wait for the UI")
        XCTAssertFalse(IntentInbox.takePendingStart(), "and be taken once")
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
