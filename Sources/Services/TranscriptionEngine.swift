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
    case loading
    case ready
    case error(String)
}

@MainActor
class TranscriptionEngine: ObservableObject {
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var modelState: ModelState = .unloaded
    @Published var selectedModel = "openai_whisper-base"
    @Published var entries: [TranscriptionEntry] = []

    let availableModels = [
        "openai_whisper-tiny",
        "openai_whisper-base",
        "openai_whisper-small"
    ]

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

    init() {
        if let data = try? Data(contentsOf: Self.historyURL),
           let saved = try? JSONDecoder().decode([TranscriptionEntry].self, from: data) {
            entries = saved
        }
    }

    func loadModel() async {
        guard modelState != .loading && modelState != .ready else { return }
        modelState = .loading
        do {
            whisperKit = try await WhisperKit(model: selectedModel)
            modelState = .ready
        } catch {
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
            try capture.startCapture { [weak self] samples in
                self?.bufferLock.withLock {
                    self?.audioBuffer.append(contentsOf: samples)
                }
            }
        } catch {
            isRecording = false
            return
        }

        recordingTask = Task {
            while !Task.isCancelled {
                await transcribeCurrentBuffer()
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    func stopRecording() async {
        isRecording = false
        recordingTask?.cancel()
        recordingTask = nil
        capture.stopCapture()
        await transcribeCurrentBuffer()

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

        do {
            let text = try await whisperKit.transcribe(audioPath: url.path).text()
            transcribedText = text
            if !text.isEmpty {
                addEntry(TranscriptionEntry(text: text, duration: 0, model: selectedModel))
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

    private func addEntry(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0)
        saveHistory()
    }

    private func transcribeCurrentBuffer() async {
        let samples: [Float] = bufferLock.withLock { audioBuffer }
        guard samples.count > 16000, let whisperKit else { return }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let text = try await whisperKit.transcribe(audioArray: samples).text()
            if !text.isEmpty { transcribedText = text }
        } catch {}
    }

    private func saveHistory() {
        try? JSONEncoder().encode(entries).write(to: Self.historyURL, options: .atomic)
    }
}
