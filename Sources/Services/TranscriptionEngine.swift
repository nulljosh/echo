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
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isCleaning = false
    @Published var audioLevel: Float = 0
    @Published var modelState: ModelState = .unloaded
    /// Progress of the background download of a better model. nil when nothing is upgrading.
    @Published var upgradeProgress: Double?
    @Published var meetingError: String?
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

    let availableModels = ["auto", "openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small_216MB", "openai_whisper-large-v3-v20240930_turbo_632MB"]
    // Every language Whisper knows (the table has aliases, so dedupe by code)
    let availableLanguages = ["auto"] + Set(Constants.languages.values).sorted()
    // ponytail: "unusual" = outside the languages the picker even offers
    private static let expectedLanguages = Set(["en", "fr", "es", "de", "zh", "ja", "ko", "ar", "pt", "ru", "it"])

    private var whisperKit: WhisperKit?
    /// A better model that finished loading while a recording was running. Swapped in at the next idle moment.
    private var pending: (kit: WhisperKit, model: String)?
    private var upgradeTask: Task<Void, Never>?
    // ponytail: test switch so the QA gate never pulls a 600 MB model
    static var downloadsEnabled = true
    private(set) var activeModel = ""
    static let tinyModel = "openai_whisper-tiny"
    /// Models that ship inside the app (tiny, base, small), so nothing ever has to download.
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
    private let capture = AudioCapture()
    #if os(macOS)
    private let systemCapture = SystemAudioCapture()
    private var mixer = AudioMixer()
    /// Meeting mode (Mac): also hear what the Mac plays, so both sides of a call are written down. No bot joins.
    @Published var meetingMode = UserDefaults.standard.bool(forKey: "notate.meetingMode") {
        didSet { UserDefaults.standard.set(meetingMode, forKey: "notate.meetingMode") }
    }
    #endif
    private let bufferLock = NSLock()
    private var audioBuffer: [Float] = []
    private var recordingTask: Task<Void, Never>?
    private var recordingStart: Date?
    private var committedText = ""
    /// Meeting mode: loudness frames (mic, call) aligned with `audioBuffer`, 100 ms each, for You/Them labels.
    private var speakerFrames: [(mic: Float, system: Float)] = []
    private var lastSpeaker: String?
    private static let commitAfterSamples = 16_000 * 15

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

    var resolvedModel: String {
        guard selectedModel == "auto" else { return selectedModel }
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        #if os(iOS)
        // ponytail: small on any 6GB+ phone (iPhone 12 and up); base was noticeably worse than Siri dictation
        if gb >= 6 { return "openai_whisper-small_216MB" }
        return gb >= 4 ? "openai_whisper-base" : "openai_whisper-tiny"
        #else
        if gb >= 8 { return "openai_whisper-small_216MB" }
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

    /// Ready in seconds with no network. Tiny ships inside the app and compiles in seconds, so it goes first.
    /// The chosen model (bundled, or downloaded once for large) loads in the background and swaps in between
    /// recordings: a bundled small model still takes the Neural Engine a minute or more to compile on first launch.
    /// False only with no bundled models.
    private func loadFastPath(_ model: String) async -> Bool {
        guard let tiny = Self.bundledTiny, let kit = try? await Self.loadBundled(tiny, fast: true) else { return false }
        whisperKit = kit; activeModel = Self.tinyModel; modelState = .ready
        if model != Self.tinyModel {
            upgradeTask = Task { [weak self] in await self?.upgrade(to: model) }
        }
        return true
    }

    /// Loads the better model without touching the UI state, then swaps it in between recordings.
    /// Bundled models never touch the network. Only a model that does not ship (large) downloads, once.
    private func upgrade(to model: String) async {
        if let bundled = Self.bundled(model) {
            guard let kit = try? await Self.loadBundled(bundled), !Task.isCancelled else { return }
            pending = (kit, model)
            applyPendingUpgrade()
            return
        }
        let fm = FileManager.default
        let stable = Self.modelCacheURL.appendingPathComponent(model)
        if let folder = cachedFolder(for: model) {
            if let kit = try? await WhisperKit(modelFolder: folder, verbose: false), !Task.isCancelled {
                pending = (kit, model)
                applyPendingUpgrade()
                return
            }
            // The cached copy is broken. Drop it and fetch it again.
            clearCachedFolder(for: model)
            try? fm.removeItem(at: stable)
        }
        guard Self.downloadsEnabled, !Task.isCancelled else { return }
        upgradeProgress = 0
        defer { upgradeProgress = nil }
        do {
            let downloaded = try await downloadWithRetry(model) { [weak self] f in self?.upgradeProgress = f }
            if Task.isCancelled { return }
            if !fm.fileExists(atPath: stable.path) {
                let tmp = Self.modelCacheURL.appendingPathComponent(model + ".tmp")
                try? fm.removeItem(at: tmp)
                if (try? fm.copyItem(at: downloaded, to: tmp)) != nil { try? fm.moveItem(at: tmp, to: stable) }
            }
            let path = fm.fileExists(atPath: stable.path) ? stable.path : downloaded.path
            let kit = try await WhisperKit(modelFolder: path, verbose: false)
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
                    whisperKit = try await WhisperKit(modelFolder: folder, verbose: false)
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
                    let kit = try await WhisperKit(modelFolder: finalPath, verbose: false)
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

    /// Feeds audio through the live path 2 s at a time, exactly as the mic would (tests).
    func simulateLive(_ samples: [Float]) async {
        committedText = ""; transcribedText = ""
        bufferLock.withLock { audioBuffer = [] }
        var i = 0
        while i < samples.count {
            let next = min(samples.count, i + 32_000)
            bufferLock.withLock { audioBuffer.append(contentsOf: samples[i..<next]) }
            i = next
            await transcribeCurrentBuffer()
        }
    }

    #if os(macOS)
    /// Feeds a mic stream and a call stream through the meeting mixer 2 s at a time, then stops (tests).
    func simulateMeeting(mic: [Float], call: [Float]) async {
        committedText = ""; transcribedText = ""; lastSpeaker = nil
        bufferLock.withLock { audioBuffer = []; speakerFrames = []; mixer = AudioMixer() }
        var i = 0
        while i < max(mic.count, call.count) {
            let m = i < mic.count ? Array(mic[i..<min(mic.count, i + 32_000)]) : []
            let c = i < call.count ? Array(call[i..<min(call.count, i + 32_000)]) : []
            bufferLock.withLock {
                audioBuffer += mixer.pushMic(m)
                audioBuffer += mixer.pushSystem(c)
                speakerFrames += mixer.takeFrames()
            }
            i += 32_000
            await transcribeCurrentBuffer()
        }
        await transcribeCurrentBuffer(full: true)
    }
    #endif

    /// Waits for the background model swap to finish (tests).
    func waitForUpgrade() async { await upgradeTask?.value }

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
        // Recording never waits on a model: audio buffers and is transcribed the moment one is ready.
        guard !isRecording else { return }
        if case .error = modelState { return }
        applyPendingUpgrade()
        isRecording = true
        transcribedText = ""
        committedText = ""
        lastSpeaker = nil
        bufferLock.withLock { audioBuffer = []; speakerFrames = [] }
        recordingStart = Date()

        #if os(macOS)
        let meeting = meetingMode
        bufferLock.withLock { mixer = AudioMixer() }
        if meeting {
            Task {
                do {
                    try await systemCapture.start { [weak self] samples in
                        guard let self else { return }
                        self.bufferLock.withLock {
                            self.audioBuffer.append(contentsOf: self.mixer.pushSystem(samples))
                            self.speakerFrames += self.mixer.takeFrames()
                        }
                    }
                    // Stop was pressed while the capture was still starting: never leave the Mac listening.
                    if !self.isRecording { self.systemCapture.stop() }
                } catch {
                    // No permission yet: keep recording the mic alone rather than failing the recording.
                    await MainActor.run { self.meetingError = "Allow Notate under Screen and System Audio Recording in System Settings to hear the call." }
                }
            }
        }
        #else
        let meeting = false
        #endif
        do {
            try capture.startCapture(
                onSamples: { [weak self] samples in
                    guard let self else { return }
                    #if os(macOS)
                    if meeting {
                        self.bufferLock.withLock {
                            self.audioBuffer.append(contentsOf: self.mixer.pushMic(samples))
                            self.speakerFrames += self.mixer.takeFrames()
                        }
                        return
                    }
                    #endif
                    self.bufferLock.withLock { self.audioBuffer.append(contentsOf: samples) }
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
        let live = recordingTask
        recordingTask = nil
        live?.cancel()
        capture.stopCapture()
        #if os(macOS)
        systemCapture.stop()
        #endif
        // Stopped before any model finished loading: wait for it so nothing said is lost.
        while whisperKit == nil, case .loading = modelState { try? await Task.sleep(for: .milliseconds(200)) }
        await live?.value // the live pass in flight finishes first, then the final pass runs alone
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

    /// Live: decodes only the audio after the last committed segment, and once that runs past 15 s, commits every
    /// finished segment and moves on. Cost stays flat however long you talk, and nothing said is ever dropped.
    /// Final (`full`): one accurate pass over the whole recording.
    private func transcribeCurrentBuffer(full: Bool = false) async {
        // The buffer only ever holds audio after the last committed segment (committed audio is dropped),
        // so memory stays flat however long a meeting runs, and the final pass only decodes the tail.
        let samples: [Float] = bufferLock.withLock {
            Array(audioBuffer.prefix(full ? audioBuffer.count : Self.liveWindowSamples))
        }
        guard samples.count > 16_000 || (full && !samples.isEmpty), let whisperKit else {
            if full, !committedText.isEmpty { transcribedText = committedText }
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: full ? decodingOptions() : liveDecodingOptions())
            if selectedLanguage == "auto", let lang = results.first?.language {
                detectedLanguage = lang
                isUnusualLanguage = !Self.expectedLanguages.contains(lang)
            }
            var segments = results.flatMap(\.segments)
            if full {
                transcribedText = appendLabelled(segments, to: committedText, speaker: &lastSpeaker)
                return
            }
            if samples.count > Self.commitAfterSamples, segments.count > 1 {
                let done = Array(segments.dropLast())
                committedText = appendLabelled(done, to: committedText, speaker: &lastSpeaker)
                let drop = min(samples.count, Int((done.last?.end ?? 0) * 16_000))
                bufferLock.withLock {
                    audioBuffer.removeFirst(min(drop, audioBuffer.count))
                    speakerFrames.removeFirst(min(speakerFrames.count, Int((Double(drop) / Double(AudioMixer.frameSamples)).rounded())))
                }
                segments = Array(segments.suffix(1))
            }
            var tailSpeaker = lastSpeaker
            let live = appendLabelled(segments, to: committedText, speaker: &tailSpeaker)
            if !live.isEmpty { transcribedText = live }
        } catch {}
    }

    /// Adds segments to `text`. In meeting mode each segment is labelled You or Them from the loudness frames, and
    /// consecutive lines from the same speaker merge. Outside meeting mode there are no frames and no labels.
    private func appendLabelled(_ segments: [TranscriptionSegment], to text: String, speaker: inout String?) -> String {
        let frames = bufferLock.withLock { speakerFrames }
        var out = text
        for seg in segments {
            let words = Self.clean(seg.text)
            guard !words.isEmpty else { continue }
            let lo = min(frames.count, max(0, Int(seg.start * 10))), hi = min(frames.count, max(lo, Int(seg.end * 10)))
            guard let who = AudioMixer.speaker(frames[lo..<hi]) else { out = Self.join(out, words); continue }
            if who == speaker { out = Self.join(out, words) } else {
                out += (out.isEmpty ? "" : "\n") + "\(who): " + words
                speaker = who
            }
        }
        return out
    }

    /// Strips Whisper's timestamp and special tokens from segment text.
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func join(_ a: String, _ b: String) -> String {
        a.isEmpty ? b : b.isEmpty ? a : a + " " + b
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
            withoutTimestamps: false
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
        entries.insert(entry, at: 0) // every transcript is kept, no cap
        saveHistory()
    }

    private func saveHistory() {
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

    private static let saveQueue = DispatchQueue(label: "notate.history", qos: .utility)
}
