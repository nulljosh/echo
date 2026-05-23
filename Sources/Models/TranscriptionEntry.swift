import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let duration: TimeInterval
    let model: String

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
