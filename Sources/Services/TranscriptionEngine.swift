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
}

@MainActor
class TranscriptionEngine: ObservableObject {
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var audioLevel: Float = 0
    @Published var modelState: ModelState = .unloaded
    @Published var selectedModel = "auto"
    @Published var selectedLanguage = "auto"
    @Published var entries: [TranscriptionEntry] = []

    let availableModels = ["auto", "openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small"]
    let availableLanguages = ["auto", "en", "fr", "es", "de", "zh", "ja", "ko", "ar", "pt", "ru", "it"]

    private var whisperKit: WhisperKit?
    private let capture = AudioCapture()
    private let bufferLock = NSLock()
    private var audioBuffer: [Float] = []
    private var recordingTask: Task<Void, Never>?
    private var recordingStart: Date?

    private static let historyURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("echo-history.json")
    }()

    private static let modelCacheURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modelDir = appSupport.appendingPathComponent("echo-models")
        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        return modelDir
    }()

    // Keyed by model name → local folder path, avoids HuggingFace on every launch
    private static let modelFolderKey = "echo.modelFolders"
    // Cap live transcription at 30s (Whisper max context); full buffer used on stop
    private static let liveWindowSamples = 16_000 * 30
    // Live preview only re-decodes a short trailing window so cost stays flat as recording grows
    private static let livePreviewSamples = 16_000 * 8

    init() {
        let args = CommandLine.arguments
        if args.contains("UITEST_RECORDING") {
            isRecording = true
            transcribedText = "the quick brown fox jumps over the lazy dog and keeps talking while the model listens in real time"
            return
        }
        if args.contains("UITEST_FINISHED") {
            transcribedText = "This is a sample finished transcript that demonstrates how Echo captures and displays spoken words with high accuracy, entirely on-device."
            return
        }
        if args.contains("UITEST_HISTORY") {
            entries = [
                TranscriptionEntry(text: "Meeting notes from this morning's standup.", duration: 42, model: "base"),
                TranscriptionEntry(text: "Voice memo about the new feature ideas.", duration: 18, model: "small"),
                TranscriptionEntry(text: "Quick reminder to call back later today.", duration: 9, model: "tiny")
            ]
            return
        }
        if let data = try? Data(contentsOf: Self.historyURL),
           let saved = try? JSONDecoder().decode([TranscriptionEntry].self, from: data) {
            entries = saved
        }
    }

    var resolvedModel: String {
        guard selectedModel == "auto" else { return selectedModel }
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gb >= 8 { return "openai_whisper-small" }
        if gb >= 4 { return "openai_whisper-base" }
        return "openai_whisper-tiny"
    }

    func loadModel() async {
        if CommandLine.arguments.contains(where: { $0.hasPrefix("UITEST_") }) {
            modelState = .ready
            return
        }
        if case .loading = modelState { return }
        guard modelState != .ready else { return }
        modelState = .loading(progress: 0)
        do {
            let model = resolvedModel
            if let folder = cachedFolder(for: model) {
                whisperKit = try await WhisperKit(modelFolder: folder)
            } else {
                let downloadedFolder = try await WhisperKit.download(
                    variant: model,
                    progressCallback: { [weak self] progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor in
                            self?.modelState = .loading(progress: fraction)
                        }
                    }
                )
                let kit = try await WhisperKit(modelFolder: downloadedFolder.path)
                cacheFolder(downloadedFolder.path, for: model)
                whisperKit = kit
            }
            modelState = .ready
        } catch {
            clearCachedFolder(for: resolvedModel)
            modelState = .error(error.localizedDescription)
        }
    }

    func reloadModel() async {
        whisperKit = nil
        modelState = .unloaded
        await loadModel()
    }

    func startRecording() {
        guard modelState == .ready, !isRecording else { return }
        isRecording = true
        transcribedText = ""
        bufferLock.withLock { audioBuffer = [] }
        recordingStart = Date()

        do {
            try capture.startCapture(
                onSamples: { [weak self] samples in
                    self?.bufferLock.withLock { self?.audioBuffer.append(contentsOf: samples) }
                },
                onLevel: { [weak self] level in
                    DispatchQueue.main.async { self?.audioLevel = level }
                }
            )
        } catch {
            isRecording = false
            return
        }

        recordingTask = Task {
            while !Task.isCancelled {
                await transcribeCurrentBuffer()
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopRecording() async {
        isRecording = false
        audioLevel = 0
        recordingTask?.cancel()
        recordingTask = nil
        capture.stopCapture()
        await transcribeCurrentBuffer(full: true)

        let duration = Date().timeIntervalSince(recordingStart ?? Date())
        let trimmed = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            addEntry(TranscriptionEntry(text: trimmed, duration: duration, model: selectedModel))
        }
        recordingStart = nil
    }

    func transcribeFile(url: URL) async {
        guard let whisperKit, modelState == .ready else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        isTranscribing = true
        transcribedText = ""
        defer { isTranscribing = false }

        let duration = (try? AVAudioFile(forReading: url))
            .map { Double($0.length) / $0.fileFormat.sampleRate } ?? 0

        do {
            let text = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: decodingOptions()).text()
            transcribedText = text
            if !text.isEmpty {
                addEntry(TranscriptionEntry(text: text, duration: duration, model: selectedModel))
            }
        } catch {
            transcribedText = "Transcription failed: \(error.localizedDescription)"
        }
    }

    func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = transcribedText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcribedText, forType: .string)
        #endif
    }

    func deleteEntry(_ entry: TranscriptionEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }

    // MARK: - Private

    private func transcribeCurrentBuffer(full: Bool = false) async {
        let samples: [Float] = bufferLock.withLock {
            let total = audioBuffer.count
            if !full {
                let window = min(Self.liveWindowSamples, Self.livePreviewSamples)
                if total > window {
                    return Array(audioBuffer[(total - window)...])
                }
            }
            return audioBuffer
        }
        guard samples.count > 16_000, let whisperKit else { return }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let opts = full ? decodingOptions() : liveDecodingOptions()
            let text = try await whisperKit.transcribe(audioArray: samples, decodeOptions: opts).text()
            if !text.isEmpty { transcribedText = text }
        } catch {}
    }

    // Accurate options for final pass and file transcription
    private func decodingOptions() -> DecodingOptions {
        DecodingOptions(language: selectedLanguage == "auto" ? nil : selectedLanguage)
    }

    // Greedy options for live batches — much faster, good enough for preview
    private func liveDecodingOptions() -> DecodingOptions {
        DecodingOptions(
            language: selectedLanguage == "auto" ? nil : selectedLanguage,
            temperature: 0,
            usePrefillPrompt: false,
            usePrefillCache: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
    }

    // MARK: - Model folder cache

    private func cachedFolder(for model: String) -> String? {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String],
              let folder = dict[model],
              FileManager.default.fileExists(atPath: folder) else { return nil }
        return folder
    }

    private func cacheFolder(_ folder: String, for model: String) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String] ?? [:]
        dict[model] = folder
        UserDefaults.standard.set(dict, forKey: Self.modelFolderKey)
    }

    private func clearCachedFolder(for model: String) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String] ?? [:]
        dict.removeValue(forKey: model)
        UserDefaults.standard.set(dict, forKey: Self.modelFolderKey)
    }

    // MARK: - History

    private func addEntry(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0)
        if entries.count > 50 { entries = Array(entries.prefix(50)) }
        saveHistory()
    }

    private func saveHistory() {
        try? JSONEncoder().encode(entries).write(to: Self.historyURL, options: .atomic)
    }
}
