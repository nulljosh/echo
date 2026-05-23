import SwiftUI

struct HistoryView: View {
    let entries: [TranscriptionEntry]
    let onDelete: (TranscriptionEntry) -> Void

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No transcriptions yet")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries) { entry in
                        HistoryRow(entry: entry)
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparatorTint(.white.opacity(0.08))
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
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(entry.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }

            Text(entry.text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(expanded ? nil : 2)

            if entry.text.count > 120 {
                Button(expanded ? "Less" : "More") {
                    expanded.toggle()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#0071e3"))
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
