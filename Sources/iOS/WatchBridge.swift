import Foundation
import WatchConnectivity

/// Receives recordings from the Apple Watch, transcribes them on this iPhone with the bundled models,
/// saves them to history and sends the text back to the watch. Nothing goes to a server.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    /// The engine the UI is using. When the system wakes the app in the background for a watch file,
    /// there is no UI yet, so the bridge makes its own.
    weak var engine: TranscriptionEngine?
    private var backgroundEngine: TranscriptionEngine?
    private var queue: [(url: URL, id: String)] = []
    private var working = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func drain() async {
        guard !working else { return }
        working = true
        defer { working = false }
        while !queue.isEmpty {
            let job = queue.removeFirst()
            let engine = self.engine ?? backgroundEngine ?? TranscriptionEngine()
            if self.engine == nil { backgroundEngine = engine }
            await engine.loadModel()
            await engine.transcribeFile(url: job.url)
            let text = engine.transcribedText
            try? FileManager.default.removeItem(at: job.url)
            guard !text.isEmpty, !text.hasPrefix("Transcription failed") else { continue }
            WCSession.default.transferUserInfo(["id": job.id, "text": text])
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The system deletes the file when this returns, so keep a copy first.
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        guard (try? FileManager.default.copyItem(at: file.fileURL, to: copy)) != nil,
              let id = file.metadata?["id"] as? String else { return }
        Task { @MainActor in
            self.queue.append((copy, id))
            await self.drain()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
