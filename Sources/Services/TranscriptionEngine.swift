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
    @Published var isCleaning = false
    @Published var audioLevel: Float = 0
    @Published var modelState: ModelState = .unloaded
    /// Progress of the background download of a better model. nil when nothing is upgrading.
    @Published var upgradeProgress: Double?
    @Published var fileProgress: Double = 0
    @Published var selectedModel = "auto"
    @Published var selectedLanguage = "auto"
    /// Names and terms the person wants spelled their way, comma or line separated. Fed to Whisper as a prompt.
    @Published var customWords: String = UserDefaults.standard.string(forKey: "notate.customWords") ?? "" {
        didSet { UserDefaults.standard.set(customWords, forKey: "notate.customWords") }
    }
    @Published var entries: [TranscriptionEntry] = []
    @Published var detectedLanguage: String?
    @Published var isUnusualLanguage = false

    let availableModels = ["auto", "openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small", "openai_whisper-large-v3-v20240930_turbo_632MB"]
    // Every language Whisper knows (the table has aliases, so dedupe by code)
    let availableLanguages = ["auto"] + Set(Constants.languages.values).sorted()
    // ponytail: "unusual" = outside the languages the picker even offers
    private static let expectedLanguages = Set(["en", "fr", "es", "de", "zh", "ja", "ko", "ar", "pt", "ru", "it"])

    private var whisperKit: WhisperKit?
    /// A better model that finished loading while a recording was running. Swapped in at the next idle moment.
    private var pending: (kit: WhisperKit, model: String)?
    private var upgradeTask: Task<Void, Never>?
    private(set) var activeModel = ""
    static let tinyModel = "openai_whisper-tiny"
    /// Models that ship inside the app (tiny, base, small), so nothing ever has to download.
    static func bundled(_ model: String) -> URL? {
        let url = Bundle.main.resourceURL?.appendingPathComponent("BundledModels/\(model)")
        return url.flatMap { FileManager.default.fileExists(atPath: $0.appendingPathComponent("AudioEncoder.mlmodelc").path) ? $0 : nil }
    }
    static var bundledTiny: URL? { bundled(tinyModel) }
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
            transcribedText = "This is a sample finished transcript that demonstrates how Notate captures and displays spoken words with high accuracy, entirely on-device."
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
        #if os(iOS)
        // ponytail: small on any 6GB+ phone (iPhone 12 and up); base was noticeably worse than Siri dictation
        if gb >= 6 { return "openai_whisper-small" }
        return gb >= 4 ? "openai_whisper-base" : "openai_whisper-tiny"
        #else
        if gb >= 8 { return "openai_whisper-small" }
        if gb >= 4 { return "openai_whisper-base" }
        return "openai_whisper-tiny"
        #endif
    }

    func loadModel() async {
        if CommandLine.arguments.contains(where: { $0.hasPrefix("UITEST_") }) {
            modelState = .ready
            return
        }
        if case .loading = modelState { return }
        guard modelState != .ready else { return }
        modelState = .loading(progress: 0)
        let model = resolvedModel
        if await loadFastPath(model) { return }
        await blockingLoad(model)
    }

    /// Ready with no network: the chosen model from the app bundle (or a good cached copy for a model that
    /// does not ship), else tiny while the chosen one downloads in the background. False only with no bundled models.
    private func loadFastPath(_ model: String) async -> Bool {
        let fm = FileManager.default
        if let folder = Self.bundled(model)?.path ?? cachedFolder(for: model) {
            if let kit = try? await WhisperKit(modelFolder: folder) {
                whisperKit = kit; activeModel = model; modelState = .ready
                return true
            }
            if Self.bundled(model) == nil {
                // The cached copy is broken. Drop it and fall back to tiny, then fetch it again.
                clearCachedFolder(for: model)
                try? fm.removeItem(at: Self.modelCacheURL.appendingPathComponent(model))
            }
        }
        guard let tiny = Self.bundledTiny, let kit = try? await WhisperKit(modelFolder: tiny.path) else { return false }
        whisperKit = kit; activeModel = Self.tinyModel; modelState = .ready
        // Only a model that does not ship (large) ever downloads, and tiny keeps working meanwhile.
        if model != Self.tinyModel, Self.bundled(model) == nil {
            upgradeTask = Task { [weak self] in await self?.upgrade(to: model) }
        }
        return true
    }

    /// Downloads and loads the better model without touching the UI state, then swaps it in between recordings.
    private func upgrade(to model: String) async {
        upgradeProgress = 0
        defer { upgradeProgress = nil }
        let fm = FileManager.default
        let stable = Self.modelCacheURL.appendingPathComponent(model)
        do {
            let downloaded = try await downloadWithRetry(model) { [weak self] f in self?.upgradeProgress = f }
            if Task.isCancelled { return }
            if !fm.fileExists(atPath: stable.path) {
                let tmp = Self.modelCacheURL.appendingPathComponent(model + ".tmp")
                try? fm.removeItem(at: tmp)
                if (try? fm.copyItem(at: downloaded, to: tmp)) != nil { try? fm.moveItem(at: tmp, to: stable) }
            }
            let path = fm.fileExists(atPath: stable.path) ? stable.path : downloaded.path
            let kit = try await WhisperKit(modelFolder: path)
            cacheFolder(path, for: model)
            pending = (kit, model)
            applyPendingUpgrade()
        } catch {
            // Stay on tiny. A broken half download must not poison the next launch.
            clearCachedFolder(for: model)
            try? fm.removeItem(at: stable)
        }
    }

    /// Swaps in the upgraded model, only when nothing is being recorded or transcribed.
    func applyPendingUpgrade() {
        guard !isRecording, !isTranscribing, let p = pending else { return }
        whisperKit = p.kit; activeModel = p.model; pending = nil
    }

    private func blockingLoad(_ model: String) async {
        let fm = FileManager.default
        let stableFolder = Self.modelCacheURL.appendingPathComponent(model)
        var lastError: Error?
        // Second pass runs only after a failed load wiped every local copy, so it starts clean.
        for _ in 0..<2 {
            var downloadedFolder: URL?
            do {
                if let folder = cachedFolder(for: model) {
                    whisperKit = try await WhisperKit(modelFolder: folder)
                } else {
                    let downloaded = try await downloadWithRetry(model) { [weak self] f in self?.modelState = .loading(progress: f) }
                    downloadedFolder = downloaded
                    // ponytail: copy to App Support so iOS cache purges don't force re-download.
                    // Copy to a temp name then move, so a kill mid-copy never leaves a half model
                    // at the stable path (that bricked every later launch).
                    if !fm.fileExists(atPath: stableFolder.path) {
                        let tmp = Self.modelCacheURL.appendingPathComponent(model + ".tmp")
                        try? fm.removeItem(at: tmp)
                        if (try? fm.copyItem(at: downloaded, to: tmp)) != nil {
                            try? fm.moveItem(at: tmp, to: stableFolder)
                        }
                    }
                    let finalPath = fm.fileExists(atPath: stableFolder.path) ? stableFolder.path : downloaded.path
                    // ponytail: CoreML compile after download can take minutes, signal "preparing" so UI doesn't look stuck at 100%
                    modelState = .loading(progress: 1)
                    let kit = try await WhisperKit(modelFolder: finalPath)
                    cacheFolder(finalPath, for: model)
                    whisperKit = kit
                }
                modelState = .ready
                return
            } catch {
                // A corrupt or half-copied model fails forever unless every copy goes.
                lastError = error
                clearCachedFolder(for: model)
                try? fm.removeItem(at: stableFolder)
                if let downloadedFolder { try? fm.removeItem(at: downloadedFolder) }
                modelState = .loading(progress: 0)
            }
        }
        modelState = .error(lastError?.localizedDescription ?? "Model failed to load")
    }

    // ponytail: HF download has no timeout, watchdog cancels a stalled attempt, 3 tries total
    private func downloadWithRetry(_ model: String, report: @escaping @MainActor (Double) -> Void) async throws -> URL {
        var lastError: Error?
        for _ in 1...3 {
            let lastProgress = Atomic()
            let download = Task.detached {
                try await WhisperKit.download(
                    variant: model,
                    useBackgroundSession: true, // ponytail: survives app suspend, avoids restart-from-0 that made "way too long" downloads
                    progressCallback: { [weak self] progress in
                        let fraction = progress.fractionCompleted
                        lastProgress.update(fraction)
                        Task { @MainActor in report(fraction) }
                    }
                )
            }
            let watchdog = Task.detached {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    if Date().timeIntervalSince(lastProgress.date) > 30 {
                        download.cancel()
                        return
                    }
                }
            }
            do {
                let folder = try await download.value
                watchdog.cancel()
                return folder
            } catch {
                watchdog.cancel()
                lastError = error
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        throw lastError ?? URLError(.timedOut)
    }

    private final class Atomic: @unchecked Sendable {
        private let lock = NSLock()
        private var _date = Date()
        var date: Date { lock.withLock { _date } }
        func update(_ fraction: Double) { lock.withLock { _date = Date() } }
    }

    func cancelUpgrade() {
        upgradeTask?.cancel(); upgradeTask = nil; pending = nil; upgradeProgress = nil
    }

    func reloadModel() async {
        cancelUpgrade()
        whisperKit = nil
        modelState = .unloaded
        await loadModel()
    }

    func startRecording() {
        guard modelState == .ready, !isRecording else { return }
        applyPendingUpgrade()
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
        applyPendingUpgrade()
    }

    func transcribeFile(url: URL) async {
        guard let whisperKit, modelState == .ready else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        isTranscribing = true
        transcribedText = ""
        fileProgress = 0
        defer { isTranscribing = false; fileProgress = 0 }

        let duration = (try? AVAudioFile(forReading: url))
            .map { Double($0.length) / $0.fileFormat.sampleRate } ?? 0

        do {
            let text = try await whisperKit.transcribe(
                audioPath: url.path,
                decodeOptions: decodingOptions(),
                callback: { [weak self] progress in
                    guard duration > 0 else { return true }
                    let elapsed = Double(progress.windowId + 1) * Double(Constants.defaultWindowSamples) / 16_000
                    Task { @MainActor in self?.fileProgress = min(0.98, elapsed / duration) }
                    return true
                }
            ).text()
            transcribedText = text
            if !text.isEmpty {
                addEntry(TranscriptionEntry(text: text, duration: duration, model: selectedModel))
            }
        } catch {
            transcribedText = "Transcription failed: \(error.localizedDescription)"
        }
    }

    /// Tidies the current transcript on device and updates its history entry too.
    func cleanUp() async {
        let original = transcribedText
        guard !original.isEmpty, !isCleaning, !isRecording, !isTranscribing else { return }
        isCleaning = true
        defer { isCleaning = false }
        guard let cleaned = try? await Cleanup.clean(original), cleaned != original else { return }
        transcribedText = cleaned
        if let i = entries.firstIndex(where: { $0.text == original }) {
            entries[i].text = cleaned  // same entry, same date
            saveHistory()
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
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: opts)
            let text = results.text()
            if !text.isEmpty { transcribedText = text }
            if selectedLanguage == "auto", let lang = results.first?.language {
                detectedLanguage = lang
                isUnusualLanguage = !Self.expectedLanguages.contains(lang)
            }
        } catch {}
    }

    // Accurate options for final pass and file transcription
    private func decodingOptions() -> DecodingOptions {
        var options = DecodingOptions(
            language: selectedLanguage == "auto" ? nil : selectedLanguage,
            concurrentWorkerCount: 4,
            chunkingStrategy: .vad
        )
        options.promptTokens = promptTokens()
        return options
    }

    /// The custom words as Whisper prompt tokens, or nil when there are none.
    private func promptTokens() -> [Int]? {
        guard let text = Self.promptText(from: customWords), let tokenizer = whisperKit?.tokenizer else { return nil }
        let tokens = tokenizer.encode(text: text).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        return tokens.isEmpty ? nil : tokens
    }

    /// "Jos, LEC\nNotate" becomes " Jos, LEC, Notate." Trimmed, deduplicated, capped so it never crowds out speech.
    static func promptText(from raw: String) -> String? {
        var seen = Set<String>()
        let words = raw.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(50)
        return words.isEmpty ? nil : " " + words.joined(separator: ", ") + "."
    }

    // Greedy options for live batches, much faster, good enough for preview
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
        // The stored absolute path dies on every app update (container UUID changes),
        // so check the stable App Support copy by name first.
        let stable = Self.modelCacheURL.appendingPathComponent(model).path
        if FileManager.default.fileExists(atPath: stable) { return stable }
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
