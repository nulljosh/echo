import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        Group {
            if store.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text("No recordings yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.entries) { entry in
                        HistoryRow(entry: entry, store: store)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        indexSet.map { store.entries[$0] }.forEach(store.delete)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: RecordingEntry
    @ObservedObject var store: RecordingStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedDate)
                    .font(.system(size: 12, weight: .medium))
                Text(entry.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.togglePlayback(entry)
            } label: {
                Image(systemName: store.playingID == entry.id ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
