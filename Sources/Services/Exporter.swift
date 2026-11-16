import SwiftUI
import UniformTypeIdentifiers

/// A transcript as plain text, Markdown, SRT subtitles or a Word document.
enum Exporter {
    enum Format: String, CaseIterable, Identifiable {
        case text = "Text", markdown = "Markdown", subtitles = "Subtitles (SRT)", word = "Word (DOCX)"
        var id: String { rawValue }
        var fileExtension: String { switch self { case .text: "txt"; case .markdown: "md"; case .subtitles: "srt"; case .word: "docx" } }
        var contentType: UTType { UTType(filenameExtension: fileExtension) ?? .plainText }
    }

    static func render(_ entry: TranscriptionEntry, as format: Format) -> String {
        switch format {
        case .text: return entry.text
        case .markdown: return markdown(entry)
        case .subtitles: return srt(entry)
        case .word: return markdown(entry)
        }
    }

    static func data(_ entry: TranscriptionEntry, as format: Format) -> Data {
        format == .word ? docx(entry) : Data(render(entry, as: format).utf8)
    }

    /// A minimal Word document: title, summary, action items, then the transcript with bold speaker names.
    static func docx(_ entry: TranscriptionEntry) -> Data {
        func esc(_ s: some StringProtocol) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        func para(_ text: some StringProtocol, bold: String? = nil, size: Int? = nil) -> String {
            let rpr = size.map { "<w:rPr><w:b/><w:sz w:val=\"\($0)\"/></w:rPr>" } ?? ""
            let lead = bold.map { "<w:r><w:rPr><w:b/></w:rPr><w:t xml:space=\"preserve\">\(esc($0)) </w:t></w:r>" } ?? ""
            return "<w:p>\(lead)<w:r>\(rpr)<w:t xml:space=\"preserve\">\(esc(text))</w:t></w:r></w:p>"
        }
        var body = para("Echo transcript", size: 36) + para(entry.formattedDate + (entry.duration > 0 ? " · \(entry.formattedDuration)" : ""))
        if let s = entry.summary {
            body += para("Summary", size: 28) + para(s.summary)
            if !s.actionItems.isEmpty { body += para("Action items", size: 28) + s.actionItems.map { para($0, bold: "☐") }.joined() }
        }
        body += para("Transcript", size: 28)
        for line in entry.text.split(separator: "\n") {
            if let who = ["You", "Them"].first(where: { line.hasPrefix($0 + ": ") }) {
                body += para(line.dropFirst(who.count + 2), bold: who + ":")
            } else { body += para(line) }
        }
        let w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        return Zip.stored([
            ("[Content_Types].xml", #"<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>"#),
            ("_rels/.rels", #"<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>"#),
            ("word/document.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"\(w)\"><w:body>\(body)</w:body></w:document>"),
        ])
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

/// An uncompressed ZIP, all a .docx needs. ponytail: stored only, add deflate if exports ever get big.
enum Zip {
    static func stored(_ files: [(String, String)]) -> Data {
        var out = Data(), central = Data()
        func u16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
        func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        for (name, text) in files {
            let n = Data(name.utf8), d = Data(text.utf8), crc = crc32(d), offset = UInt32(out.count)
            let common = u16(20) + u16(0) + u16(0) + u16(0) + u16(0x21) + u32(crc) + u32(UInt32(d.count)) + u32(UInt32(d.count)) + u16(n.count) + u16(0)
            out += u32(0x04034b50) + common + n + d
            central += u32(0x02014b50) + u16(20) + common + u16(0) + u16(0) + u16(0) + u32(0) + u32(offset) + n
        }
        let end = u32(0x06054b50) + u16(0) + u16(0) + u16(files.count) + u16(files.count) + u32(UInt32(central.count)) + u32(UInt32(out.count)) + u16(0)
        return out + central + end
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data {
            c ^= UInt32(b)
            for _ in 0..<8 { c = c & 1 == 1 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        }
        return ~c
    }
}

/// The exported transcript as a file for the save panel.
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { Exporter.Format.allCases.map(\.contentType) + [.plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
