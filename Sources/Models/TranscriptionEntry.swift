import Foundation

/// One stretch of speech with its time in the recording and, in meeting mode, who said it.
struct TimedLine: Codable, Equatable {
    var start: Double
    var end: Double
    var text: String
    var speaker: String?
}

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    var text: String
    let date: Date
    let duration: TimeInterval
    let model: String
    /// On-device summary and action items, once asked for.
    var summary: TranscriptSummary?
    /// Timed lines (seconds from the start), for subtitles. Older entries have none.
    var lines: [TimedLine]?

    init(text: String, duration: TimeInterval, model: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.duration = duration
        self.model = model
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
