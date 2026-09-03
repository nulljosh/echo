import Foundation
import AVFoundation
import Combine

/// Records, persists, and plays back voice memos entirely on-device.
///
/// This mirrors the iPhone/Mac app's "no cloud, nothing uploaded" pledge:
/// audio is captured with `AVAudioRecorder`, saved as `.m4a` files under the
/// watch's own Documents directory, and indexed in a small JSON manifest
/// (`recordings.json`), the same pattern the main app uses for its own
/// history file. The watch app is standalone (`WKWatchOnly`) and does not
/// require the iPhone to be nearby to record or play back.
@MainActor
final class RecordingStore: NSObject, ObservableObject {
    @Published private(set) var entries: [RecordingEntry] = []
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var playingID: UUID?
    @Published var errorMessage: String?

    static nonisolated let recordingsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var manifestURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings.json")
    }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private var recordingStart: Date?

    override init() {
        super.init()
        load()
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Couldn't access the microphone."
            return
        }

        let fileName = "\(UUID().uuidString).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.delegate = self
            recorder.record()
            self.recorder = recorder
            self.pendingFileName = fileName
            recordingStart = Date()
            isRecording = true
            elapsed = 0
            startMetering()
        } catch {
            errorMessage = "Couldn't start recording."
        }
    }

    func stopRecording() {
        guard isRecording, let recorder else { return }
        recorder.stop()
        finishRecording(duration: Date().timeIntervalSince(recordingStart ?? Date()))
    }

    private var pendingFileName: String?

    private func finishRecording(duration: TimeInterval) {
        stopMetering()
        isRecording = false
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let fileName = pendingFileName else { return }
        pendingFileName = nil

        let entry = RecordingEntry(fileName: fileName, duration: duration)
        entries.insert(entry, at: 0)
        save()
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                // Map dBFS (-160...0) to a 0...1 level for the waveform view.
                let normalized = max(0, min(1, (db + 50) / 50))
                self.level = normalized
                self.elapsed = Date().timeIntervalSince(self.recordingStart ?? Date())
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }

    // MARK: - Playback

    func togglePlayback(_ entry: RecordingEntry) {
        if playingID == entry.id {
            stopPlayback()
            return
        }
        stopPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: entry.fileURL)
            player.delegate = self
            player.play()
            self.player = player
            playingID = entry.id
        } catch {
            errorMessage = "Couldn't play that recording."
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
    }

    // MARK: - Deleting

    func delete(_ entry: RecordingEntry) {
        if playingID == entry.id { stopPlayback() }
        try? FileManager.default.removeItem(at: entry.fileURL)
        entries.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.manifestURL),
              let decoded = try? JSONDecoder().decode([RecordingEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.manifestURL, options: .atomic)
    }
}

extension RecordingStore: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.isRecording else { return }
            if !flag {
                self.errorMessage = "Recording didn't finish cleanly."
                self.pendingFileName = nil
                self.isRecording = false
                self.stopMetering()
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopPlayback()
        }
    }
}
