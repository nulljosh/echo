import AVFoundation
import Foundation
import WhisperKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension [TranscriptionResult] {
    func text() -> String {
        map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ModelState: Equatable {
    case unloaded
    case loading(progress: Double = 0)
    case ready
    case error(String)

    var isError: Bool { if case .error = self { return true } else { return false } }
}

@MainActor
class TranscriptionEngine: ObservableObject {
    /// Where the engine's settings live. Under XCTest they go to their own suite, so a test run never rewrites
    /// the real app's model, language, custom words or meeting mode on this Mac.
    static let settings = NSClassFromString("XCTestCase") == nil ? UserDefaults.standard : UserDefaults(suiteName: "echo-tests")!

    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isCleaning = false
    @Published var isSummarizing = false
    /// The summary of the transcript on screen, shown in a sheet.
    @Published var summary: TranscriptSummary?
    @Published var audioLevel: Float = 0
    @Published var modelState: ModelState = .unloaded
    /// Progress of the background download of a better model. nil when nothing is upgrading.
    @Published var upgradeProgress: Double?
    /// A problem worth telling the person about (no microphone, no call audio permission). Shown as an alert.
    @Published var notice: String?
    @Published var fileProgress: Double = 0
    @Published var selectedModel = TranscriptionEngine.settings.string(forKey: "echo.selectedModel") ?? "auto" {
        didSet { TranscriptionEngine.settings.set(selectedModel, forKey: "echo.selectedModel") }
    }
    @Published var selectedLanguage = TranscriptionEngine.settings.string(forKey: "echo.selectedLanguage") ?? "auto" {
        didSet { TranscriptionEngine.settings.set(selectedLanguage, forKey: "echo.selectedLanguage") }
    }
    /// Names and terms the person wants spelled their way, comma or line separated. Fed to Whisper as a prompt.
    @Published var customWords: String = TranscriptionEngine.settings.string(forKey: "notate.customWords") ?? "" {
        didSet { TranscriptionEngine.settings.set(customWords, forKey: "notate.customWords") }
    }
    @Published var entries: [TranscriptionEntry] = []
    @Published var detectedLanguage: String?
    @Published var isUnusualLanguage = false

    let availableModels = ["auto", "openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small_216MB", "openai_whisper-large-v3-v20240930_turbo_632MB"]
        + (AppleSpeech.isSupported ? [AppleSpeech.modelID] : [])
    // Every language Whisper knows (the table has aliases, so dedupe by code)
    let availableLanguages = ["auto"] + Set(Constants.languages.values).sorted()
    // ponytail: "unusual" = outside the languages the picker even offers
    static let expectedLanguages = Set(["en", "fr", "es", "de", "zh", "ja", "ko", "ar", "pt", "ru", "it"])

    var whisperKit: WhisperKit?
    /// A better model that finished loading while a recording was running. Swapped in at the next idle moment.
    var pending: (kit: WhisperKit, model: String)?
    var upgradeTask: Task<Void, Never>?
    // ponytail: test switch so the QA gate never pulls a 600 MB model
    static var downloadsEnabled = true
    var activeModel = ""
    static let tinyModel = "openai_whisper-tiny"
    /// Models that ship inside the app (tiny, small), so nothing ever has to download.
    static func bundled(_ model: String) -> URL? {
        let url = Bundle.main.resourceURL?.appendingPathComponent("BundledModels/\(model)")
        return url.flatMap { FileManager.default.fileExists(atPath: $0.appendingPathComponent("AudioEncoder.mlmodelc").path) ? $0 : nil }
    }
    static var bundledTiny: URL? { bundled(tinyModel) }
    /// Loads a model that ships in the app. The tokenizer comes from the same folder, so no network at all.
    /// `fast` runs on the GPU: ready in seconds on first launch, where the Neural Engine first compiles for minutes.
    static func loadBundled(_ folder: URL, fast: Bool = false) async throws -> WhisperKit {
        let gpu = ModelComputeOptions(melCompute: .cpuAndGPU, audioEncoderCompute: .cpuAndGPU, textDecoderCompute: .cpuAndGPU, prefillCompute: .cpuOnly)
        return try await WhisperKit(modelFolder: folder.path, tokenizerFolder: folder, computeOptions: fast ? gpu : nil, verbose: false, download: false)
    }
    let capture = AudioCapture()
    #if os(macOS)
    let systemCapture = SystemAudioCapture()
    var mixer = AudioMixer()
    /// Meeting mode (Mac): also hear what the Mac plays, so both sides of a call are written down. No bot joins.
    @Published var meetingMode = TranscriptionEngine.settings.bool(forKey: "notate.meetingMode") {
        didSet { TranscriptionEngine.settings.set(meetingMode, forKey: "notate.meetingMode") }
    }
    #endif
    let bufferLock = NSLock()
    var audioBuffer: [Float] = []
    var recordingTask: Task<Void, Never>?
    var recordingStart: Date?
    var committedText = ""
    /// The live Apple session while one is recording (an AppleSpeech.Live, typed loosely for iOS 17).
    var appleSession: AnyObject?
    /// Meeting mode: loudness frames (mic, call) aligned with `audioBuffer`, 100 ms each, for You/Them labels.
    var speakerFrames: [(mic: Float, system: Float)] = []
    var lastSpeaker: String?
    /// Timed lines already committed this recording, and how many seconds of audio were dropped before the buffer.
    var committedLines: [TimedLine] = []
    var bufferOffset: Double = 0
    var finalLines: [TimedLine] = []
    static let commitAfterSamples = 16_000 * 15

    static let historyURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("echo-history.json")
    }()

    static let modelCacheURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modelDir = appSupport.appendingPathComponent("echo-models")
        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        return modelDir
    }()

    // Keyed by model name → local folder path, avoids HuggingFace on every launch
    static let modelFolderKey = "echo.modelFolders"
    // Cap live transcription at 30s (Whisper max context); full buffer used on stop
    static let liveWindowSamples = 16_000 * 30

    init() {
        // Leading dashes allowed: on the Mac a bare word is taken as a document to open and the window never shows.
        let args = CommandLine.arguments.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
        if args.contains("UITEST_RECORDING") {
            entries = Self.sampleEntries
            isRecording = true
            transcribedText = "the quick brown fox jumps over the lazy dog and keeps talking while the model listens in real time"
            return
        }
        if args.contains("UITEST_FINISHED") || args.contains("UITEST_SUMMARY") {
            entries = Self.sampleEntries // the Mac sidebar shows history next to the transcript
            transcribedText = "You: Can we move the launch to Thursday so design has one more day?\nThem: Thursday works. I'll tell the store team and update the plan tonight.\nYou: Great. I'll send the final screenshots by Wednesday noon."
            if args.contains("UITEST_SUMMARY") {
                summary = TranscriptSummary(summary: "The launch moves to Thursday to give design one more day. The store team will be told tonight.",
                                            actionItems: ["Them: tell the store team and update the plan tonight", "You: send the final screenshots by Wednesday noon"])
            }
            return
        }
        if args.contains("UITEST_HISTORY") {
            entries = Self.sampleEntries
            return
        }
        if let data = try? Data(contentsOf: Self.historyURL) {
            if let saved = try? JSONDecoder().decode([TranscriptionEntry].self, from: data) {
                entries = saved
            } else {
                // Unreadable history is set aside, never overwritten by the next save.
                let aside = Self.historyURL.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: Self.historyURL, to: aside)
            }
        }
    }

    /// Mock history for App Store screenshots.
    static let sampleEntries = [
        TranscriptionEntry(text: "You: Can we move the launch to Thursday so design has one more day? Them: Thursday works.", duration: 754, model: "small"),
        TranscriptionEntry(text: "Ideas for the onboarding: one screen, record button first, no account.", duration: 48, model: "small"),
        TranscriptionEntry(text: "Pick up oat milk, call the dentist back, book the flight for Friday.", duration: 12, model: "small")
    ]

    var resolvedModel: String {
        // "apple" handles files; live recording still needs a Whisper model, picked the auto way.
        guard selectedModel == "auto" || selectedModel == AppleSpeech.modelID else { return selectedModel }
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        #if os(iOS)
        // ponytail: small on any 6GB+ phone (iPhone 12 and up), tiny below. Auto only picks what ships in the app;
        // base (143 MB) stopped shipping in 2.5 because small is more accurate. It is still a download in Settings.
        return gb >= 6 ? "openai_whisper-small_216MB" : "openai_whisper-tiny"
        #else
        return gb >= 8 ? "openai_whisper-small_216MB" : "openai_whisper-tiny"
        #endif
    }


    /// The history entry for the transcript on screen, or a fresh one when it was never saved.
    var currentEntry: TranscriptionEntry? {
        guard !transcribedText.isEmpty else { return nil }
        return entries.first { $0.text == transcribedText } ?? TranscriptionEntry(text: transcribedText, duration: 0, model: activeModel)
    }

    /// Strips Whisper's timestamp and special tokens from segment text.
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func join(_ a: String, _ b: String) -> String {
        a.isEmpty ? b : b.isEmpty ? a : a + " " + b
    }

    // MARK: - History

    func addEntry(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0) // every transcript is kept, no cap
        saveHistory()
    }

    func saveHistory() {
        let snapshot = entries
        let url = Self.historyURL
        // Off the main thread: with no cap, history can grow to megabytes. Saves run in order on one queue.
        Self.saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            #if os(iOS)
            // Transcripts are private: encrypted at rest while the phone is locked (new files can still be written).
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            #else
            try? data.write(to: url, options: .atomic)
            #endif
        }
    }

    static let saveQueue = DispatchQueue(label: "notate.history", qos: .utility)
}
