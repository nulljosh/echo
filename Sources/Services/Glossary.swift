import Foundation

/// Whisper has no hotword list and the prompt bias is weak, so custom words also fix the text afterwards:
/// a heard word (or two words run together, "jay bulb") within a letter or two of a glossary term becomes the term.
enum Glossary {
    // ponytail: single-word terms only, edit distance not phonetics; add Soundex/Metaphone if names still slip through.
    static func apply(_ text: String, words raw: String) -> String {
        let terms = raw.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") }
        guard !terms.isEmpty, let rx = try? NSRegularExpression(pattern: "[\\p{L}\\p{N}]+") else { return text }
        let ns = text as NSString
        let found = rx.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range)
        var out = "", pos = 0, i = 0
        while i < found.count {
            let a = found[i]
            var end = a.location + a.length, take = 1
            var term = match(ns.substring(with: a), terms)
            if i + 1 < found.count, found[i + 1].location == end + 1, ns.character(at: end) == 32,
               let merged = match(ns.substring(with: a) + ns.substring(with: found[i + 1]), terms) {
                term = merged; take = 2; end = found[i + 1].location + found[i + 1].length
            }
            if let term {
                out += ns.substring(with: NSRange(location: pos, length: a.location - pos)) + term
                pos = end
            }
            i += take
        }
        return out + ns.substring(from: pos)
    }

    /// The term a heard word stands for: same letters ignoring case, or a long enough term one edit away
    /// (two for 9+ letters) with the same first letter. Short terms only match exactly so "echo" never eats "eco".
    static func match(_ word: String, _ terms: [String]) -> String? {
        let w = Array(word.lowercased())
        for term in terms {
            let t = Array(term.lowercased())
            if w == t { return term }
            guard t.count >= 5, w.first == t.first, abs(w.count - t.count) <= 2 else { continue }
            if distance(w, t) <= (t.count >= 9 ? 2 : 1) { return term }
        }
        return nil
    }

    static func distance(_ a: [Character], _ b: [Character]) -> Int {
        var row = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var prev = row[0]
            row[0] = i + 1
            for (j, cb) in b.enumerated() {
                let up = row[j + 1]
                row[j + 1] = min(up + 1, row[j] + 1, prev + (ca == cb ? 0 : 1))
                prev = up
            }
        }
        return row[b.count]
    }
}
