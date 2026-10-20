import AVFoundation
import Foundation
import WhisperKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Files, clean up, summary and the history actions on screen.
@MainActor
extension TranscriptionEngine {
    func transcribeFile(url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if selectedModel == AppleSpeech.modelID, let locale = await AppleSpeech.installedLocale(for: selectedLanguage) {
            await transcribeFileWithApple(url: url, locale: locale)
            return
        }
        guard let whisperKit, modelState == .ready else { return }

        isTranscribing = true
        transcribedText = ""
        fileProgress = 0
        defer { isTranscribing = false; fileProgress = 0 }

        let duration = (try? AVAudioFile(forReading: url))
            .map { Double($0.length) / $0.fileFormat.sampleRate } ?? 0

        do {
            let results = try await whisperKit.transcribe(
                audioPath: url.path,
                decodeOptions: decodingOptions(),
                callback: { [weak self] progress in
                    guard duration > 0 else { return true }
                    let elapsed = Double(progress.windowId + 1) * Double(Constants.defaultWindowSamples) / 16_000
                    Task { @MainActor in self?.fileProgress = min(0.98, elapsed / duration) }
                    return true
                }
            )
            let text = results.text()
            transcribedText = text
            if !text.isEmpty {
                var entry = TranscriptionEntry(text: text, duration: duration, model: selectedModel)
                let lines = timedLines(results.flatMap(\.segments), offset: 0)
                entry.lines = lines.isEmpty ? nil : lines
                addEntry(entry)
            }
        } catch {
            transcribedText = "Transcription failed: \(error.localizedDescription)"
        }
    }

    func transcribeFileWithApple(url: URL, locale: Locale) async {
        isTranscribing = true
        transcribedText = ""
        defer { isTranscribing = false }
        let duration = (try? AVAudioFile(forReading: url)).map { Double($0.length) / $0.fileFormat.sampleRate } ?? 0
        do {
            let lines = try await AppleSpeech.transcribe(url: url, locale: locale)
            let text = lines.map(\.text).joined(separator: " ")
            transcribedText = text
            guard !text.isEmpty else { return }
            var entry = TranscriptionEntry(text: text, duration: duration, model: AppleSpeech.modelID)
            entry.lines = lines
            addEntry(entry)
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

    /// Summary and action items for the transcript on screen, on device. Saved with its history entry.
    func summarize() async {
        let text = transcribedText
        guard !text.isEmpty, !isSummarizing, !isRecording, !isTranscribing else { return }
        if let i = entries.firstIndex(where: { $0.text == text }), let saved = entries[i].summary { summary = saved; return }
        isSummarizing = true
        defer { isSummarizing = false }
        guard let result = try? await Summarizer.summarize(text) else { return }
        summary = result
        if let i = entries.firstIndex(where: { $0.text == text }) {
            entries[i].summary = result
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

}
