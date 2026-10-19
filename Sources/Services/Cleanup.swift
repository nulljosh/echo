import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One-tap tidy-up of a transcript with Apple's on-device model. Nothing leaves the device.
/// Only offered where the system model exists and is ready (Apple Intelligence on, iOS or macOS 26+).
enum Cleanup {
    static let instructions = """
        You tidy dictated text. Fix punctuation, capitalization and grammar, and remove filler words \
        like um, uh, and you know. Keep the speaker's own words, meaning and language. Do not add, \
        summarize or answer anything. Reply with only the cleaned text.
        """

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    static func clean(_ text: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: instructions)
            let reply = try await session.respond(to: text)
            let cleaned = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // A blank or runaway answer is worse than the original. Keep what was said.
            guard !cleaned.isEmpty, cleaned.count < text.count * 2 + 40 else { return text }
            return cleaned
        }
        #endif
        return text
    }
}

/// A short summary and the action items of a transcript.
struct TranscriptSummary: Codable, Equatable {
    var summary: String
    var actionItems: [String]
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GeneratedNotes {
    @Guide(description: "Two or three plain sentences saying what was discussed or said. No preamble.")
    var summary: String
    @Guide(description: "Concrete tasks someone said they or another person will do, each one short, starting with who if known. Empty when there are none.")
    var actionItems: [String]
}
#endif

/// Summary and action items with Apple's on-device model. Nothing leaves the device. Same availability as Cleanup.
enum Summarizer {
    static let instructions = """
        You read transcripts of speech and meetings. Summarize only what is in the transcript, in its language. \
        Never invent tasks, names or dates. Lines may start with You: or Them: to say who spoke.
        """
    // ponytail: chars per chunk keeps each request well inside the on-device context window
    static let chunkChars = 6_000

    static func summarize(_ text: String) async throws -> TranscriptSummary? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard Cleanup.isAvailable, !text.isEmpty else { return nil }
            // Long transcripts: notes per chunk first, then one pass over the notes.
            var source = text
            if text.count > chunkChars {
                var notes: [String] = []
                var rest = Substring(text)
                while !rest.isEmpty {
                    let piece = rest.prefix(chunkChars)
                    rest = rest.dropFirst(piece.count)
                    let part = try await notesFor(String(piece))
                    notes.append(part.summary + (part.actionItems.isEmpty ? "" : " Tasks: " + part.actionItems.joined(separator: "; ")))
                }
                source = notes.joined(separator: "\n")
            }
            let final = try await notesFor(source)
            return TranscriptSummary(summary: final.summary.trimmingCharacters(in: .whitespacesAndNewlines),
                                     actionItems: final.actionItems.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func notesFor(_ text: String) async throws -> GeneratedNotes {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: "Transcript:\n" + text, generating: GeneratedNotes.self).content
    }
    #endif
}
