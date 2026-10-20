import SwiftUI

struct HistoryView: View {
    let entries: [TranscriptionEntry]
    let onDelete: (TranscriptionEntry) -> Void
    @ObservedObject var speech: SpeechManager
    @State private var query = ""

    /// Every word of the search must appear in the transcript or its summary. Case and accents don't matter.
    static func matches(_ entry: TranscriptionEntry, _ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = entry.text + " " + (entry.summary.map { $0.summary + " " + $0.actionItems.joined(separator: " ") } ?? "")
        return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private var shown: [TranscriptionEntry] { entries.filter { Self.matches($0, query) } }

    #if os(macOS)
    private let searchPlacement = SearchFieldPlacement.sidebar
    #else
    private let searchPlacement = SearchFieldPlacement.automatic
    #endif

    var body: some View {
        List {
            ForEach(shown) { entry in
                HistoryRow(entry: entry, speech: speech) { onDelete(entry) }
            }
            .onDelete { indexSet in
                let rows = shown
                indexSet.map { rows[$0] }.forEach(onDelete)
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("No Transcriptions", systemImage: "waveform", description: Text("Everything you record shows up here."))
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: searchPlacement, prompt: "Search everything said")
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    @ObservedObject var speech: SpeechManager
    let onDelete: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.echo(13, .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.formattedDuration)
                    .font(.echo(13))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Text(entry.text)
                .font(.echo(15))
                .lineLimit(expanded ? nil : 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
        .contextMenu {
            Button {
                speech.toggle(id: entry.id, text: entry.text, languageCode: nil)
            } label: {
                speech.speakingID == entry.id
                    ? Label("Stop Reading", systemImage: "stop")
                    : Label("Read Aloud", systemImage: "speaker.wave.2")
            }
            ShareLink("Share", item: entry.text)
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}
