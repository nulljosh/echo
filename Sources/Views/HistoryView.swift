import SwiftUI

struct HistoryView: View {
    let entries: [TranscriptionEntry]
    let onDelete: (TranscriptionEntry) -> Void
    @ObservedObject var speech: SpeechManager

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.notate(28))
                        .foregroundStyle(.tertiary)
                    Text("No transcriptions yet")
                        .font(.notate(13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries) { entry in
                        HistoryRow(entry: entry, speech: speech)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        indexSet.map { entries[$0] }.forEach(onDelete)
                    }
                }
                .scrollContentBackground(.hidden)
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
                    .font(.notate(11, .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.formattedDuration)
                    .font(.notate(11))
                    .foregroundStyle(.tertiary)
                Button {
                    speech.toggle(id: entry.id, text: entry.text, languageCode: nil)
                } label: {
                    Image(systemName: speech.speakingID == entry.id ? "stop.circle.fill" : "speaker.wave.2.circle")
                        .font(.notate(14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(entry.text)
                .font(.notate(13))
                .foregroundStyle(.primary)
                .lineLimit(expanded ? nil : 2)

            if entry.text.count > 120 {
                Button(expanded ? "Less" : "More") {
                    expanded.toggle()
                }
                .font(.notate(11, .medium))
                .foregroundStyle(.tint)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
