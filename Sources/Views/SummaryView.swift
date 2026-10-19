import SwiftUI

struct SummaryBox: Identifiable {
    let summary: TranscriptSummary
    var id: String { summary.summary }
}

/// The summary and action items of a transcript, made on device.
struct SummaryView: View {
    let summary: TranscriptSummary
    @Environment(\.dismiss) private var dismiss

    private var asText: String {
        summary.summary + (summary.actionItems.isEmpty ? "" : "\n\nAction items\n" + summary.actionItems.map { "- " + $0 }.joined(separator: "\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Summary").font(.notate(22, .bold))
            Text(summary.summary).font(.notate(17)).lineSpacing(3).textSelection(.enabled)
            if !summary.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action items").font(.notate(15, .semibold)).foregroundStyle(.secondary)
                    ForEach(summary.actionItems, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "circle").font(.notate(13)).foregroundStyle(Color.accentColor)
                            Text(item).font(.notate(17)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                ShareLink(item: asText) {
                    Text("Share").font(.notate(17, .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                Button { dismiss() } label: {
                    Text("Done").font(.notate(17, .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .presentationDetents([.medium, .large])
    }
}
