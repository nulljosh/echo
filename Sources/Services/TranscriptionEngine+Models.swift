import AVFoundation
import Foundation
import WhisperKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Loading, upgrading and caching Whisper models. Read the model notes in CLAUDE.md before touching this.
@MainActor
extension TranscriptionEngine {
    func loadModel() async {
        if CommandLine.arguments.contains(where: { $0.hasPrefix("UITEST_") || $0.hasPrefix("-UITEST_") }) {
            modelState = .ready
            return
        }
        if selectedModel == "auto" || selectedModel == AppleSpeech.modelID {
            let language = selectedLanguage
            Task.detached(priority: .background) { await AppleSpeech.prepare(for: language) }
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
    func loadFastPath(_ model: String) async -> Bool {
        guard let tiny = Self.bundledTiny, let kit = try? await Self.loadBundled(tiny, fast: true) else { return false }
        whisperKit = kit; activeModel = Self.tinyModel; modelState = .ready
        if model != Self.tinyModel {
            upgradeTask = Task { [weak self] in await self?.upgrade(to: model) }
        }
        return true
    }

    /// Loads the better model without touching the UI state, then swaps it in between recordings.
    /// Bundled models never touch the network. Only a model that does not ship (large) downloads, once.
    func upgrade(to model: String) async {
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

    func blockingLoad(_ model: String) async {
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
    func downloadWithRetry(_ model: String, report: @escaping @MainActor (Double) -> Void) async throws -> URL {
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

    final class Atomic: @unchecked Sendable {
        private let lock = NSLock()
        private var _date = Date()
        var date: Date { lock.withLock { _date } }
        func update(_ fraction: Double) { lock.withLock { _date = Date() } }
    }


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


    // MARK: - Model folder cache

    func cachedFolder(for model: String) -> String? {
        // The stored absolute path dies on every app update (container UUID changes),
        // so check the stable App Support copy by name first.
        let stable = Self.modelCacheURL.appendingPathComponent(model).path
        if FileManager.default.fileExists(atPath: stable) { return stable }
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String],
              let folder = dict[model],
              FileManager.default.fileExists(atPath: folder) else { return nil }
        return folder
    }

    func cacheFolder(_ folder: String, for model: String) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String] ?? [:]
        dict[model] = folder
        UserDefaults.standard.set(dict, forKey: Self.modelFolderKey)
    }

    func clearCachedFolder(for model: String) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.modelFolderKey) as? [String: String] ?? [:]
        dict.removeValue(forKey: model)
        UserDefaults.standard.set(dict, forKey: Self.modelFolderKey)
    }

}
