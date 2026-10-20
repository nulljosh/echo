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

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.echo(28))
                        .foregroundStyle(.tertiary)
                    Text("No transcriptions yet")
                        .font(.echo(13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                        TextField("Search everything said", text: $query)
                            .textFieldStyle(.plain)
                            .font(.echo(15))
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(.quaternary.opacity(0.5), in: Capsule())
                    .padding(.horizontal, 12)

                    if shown.isEmpty {
                        Text("Nothing matches")
                            .font(.echo(13))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(shown) { entry in
                                HistoryRow(entry: entry, speech: speech)
                                    .listRowBackground(Color.clear)
                            }
                            .onDelete { indexSet in
                                let rows = shown
                                indexSet.map { rows[$0] }.forEach(onDelete)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    @ObservedObject var speech: SpeechManager
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.formattedDate)
                    .font(.echo(11, .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.formattedDuration)
                    .font(.echo(11))
                    .foregroundStyle(.tertiary)
                Button {
                    speech.toggle(id: entry.id, text: entry.text, languageCode: nil)
                } label: {
                    Image(systemName: speech.speakingID == entry.id ? "stop.circle.fill" : "speaker.wave.2.circle")
                        .font(.echo(14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(entry.text)
                .font(.echo(13))
                .foregroundStyle(.primary)
                .lineLimit(expanded ? nil : 2)

            if entry.text.count > 120 {
                Button(expanded ? "Less" : "More") {
                    expanded.toggle()
                }
                .font(.echo(11, .medium))
                .foregroundStyle(.tint)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
