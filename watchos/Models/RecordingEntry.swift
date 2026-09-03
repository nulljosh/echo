import Foundation

/// A single on-watch voice memo. Voxprint's transcription runs entirely on
/// the paired iPhone/Mac via WhisperKit; the watch app only captures and
/// stores raw audio locally, nothing is transcribed or uploaded here.
struct RecordingEntry: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let date: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), fileName: String, date: Date = Date(), duration: TimeInterval) {
        self.id = id
        self.fileName = fileName
        self.date = date
        self.duration = duration
    }

    var fileURL: URL {
        RecordingStore.recordingsDirectory.appendingPathComponent(fileName)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    var formattedDuration: String {
        let s = Int(duration)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }
}
