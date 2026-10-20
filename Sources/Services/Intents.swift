import AppIntents
import Foundation

/// Hands a "start recording" request from Shortcuts, Siri or the Action button to the app, whether it was running or not.
@MainActor
enum IntentInbox {
    static let startRecording = Notification.Name("notate.startRecording")
    /// Set when the intent launched the app before the UI was listening; the UI takes it once ready.
    static var pendingStart = false

    static func requestStart() {
        pendingStart = true
        NotificationCenter.default.post(name: startRecording, object: nil)
    }

    static func takePendingStart() -> Bool { defer { pendingStart = false }; return pendingStart }
}

/// Opens Echo already recording. Pin it to the Action button, a Shortcut or ask Siri.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Opens Echo and starts transcribing what you say, on device.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentInbox.requestStart()
        return .result()
    }
}

/// Transcribes an audio file on device and returns the text, without opening the app.
struct TranscribeAudioIntent: AppIntent {
    static let title: LocalizedStringResource = "Transcribe Audio"
    static let description = IntentDescription("Turns an audio file into text with Echo's built-in model. Nothing leaves your device.")

    @Parameter(title: "Audio")
    var audio: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let ext = audio.filename.split(separator: ".").last.map(String.init) ?? "m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        try audio.data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = TranscriptionEngine()
        await engine.loadModel()
        await engine.transcribeFile(url: url)
        let text = engine.transcribedText
        guard !text.isEmpty, !text.hasPrefix("Transcription failed") else {
            throw NSError(domain: "Echo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't hear any speech in that audio."])
        }
        return .result(value: text)
    }
}

struct EchoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRecordingIntent(), phrases: ["Start a recording in \(.applicationName)", "Transcribe with \(.applicationName)"],
                    shortTitle: "Start Recording", systemImageName: "mic.fill")
        AppShortcut(intent: TranscribeAudioIntent(), phrases: ["Transcribe audio with \(.applicationName)"],
                    shortTitle: "Transcribe Audio", systemImageName: "waveform")
    }
}
