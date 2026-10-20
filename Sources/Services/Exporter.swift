import SwiftUI
import UniformTypeIdentifiers

/// A transcript as plain text, Markdown or SRT subtitles.
enum Exporter {
    enum Format: String, CaseIterable, Identifiable {
        case text = "Text", markdown = "Markdown", subtitles = "Subtitles (SRT)"
        var id: String { rawValue }
        var fileExtension: String { switch self { case .text: "txt"; case .markdown: "md"; case .subtitles: "srt" } }
        var contentType: UTType { UTType(filenameExtension: fileExtension) ?? .plainText }
    }

    static func render(_ entry: TranscriptionEntry, as format: Format) -> String {
        switch format {
        case .text: return entry.text
        case .markdown: return markdown(entry)
        case .subtitles: return srt(entry)
        }
    }

    static func markdown(_ entry: TranscriptionEntry) -> String {
        var out = "# Echo transcript\n\n\(entry.formattedDate)" + (entry.duration > 0 ? " · \(entry.formattedDuration)" : "") + "\n"
        if let s = entry.summary {
            out += "\n## Summary\n\n\(s.summary)\n"
            if !s.actionItems.isEmpty { out += "\n## Action items\n\n" + s.actionItems.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n" }
        }
        // Speaker lines ("You: ...") read as bold names.
        let body = entry.text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            for who in ["You", "Them"] where line.hasPrefix(who + ": ") { return "**\(who):** " + line.dropFirst(who.count + 2) }
            return String(line)
        }.joined(separator: "\n\n")
        return out + "\n## Transcript\n\n" + body + "\n"
    }

    static func srt(_ entry: TranscriptionEntry) -> String {
        // Older entries have no timings: one cue for the whole recording.
        let lines = entry.lines ?? [TimedLine(start: 0, end: max(entry.duration, 1), text: entry.text, speaker: nil)]
        return lines.enumerated().map { i, l in
            "\(i + 1)\n\(stamp(l.start)) --> \(stamp(max(l.end, l.start + 0.5)))\n" + (l.speaker.map { "\($0): " } ?? "") + l.text + "\n"
        }.joined(separator: "\n")
    }

    /// 00:01:02,345
    static func stamp(_ seconds: Double) -> String {
        let ms = Int((max(0, seconds) * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
    }
}

/// The exported transcript as a file for the save panel.
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { Exporter.Format.allCases.map(\.contentType) + [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
