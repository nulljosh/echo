import SwiftUI

private let whatsNewVersion = "2.2"
private let whatsNewBullets = [
    "A cleaner look: one record button, Liquid Glass, and the word you're saying pops in as you talk",
    "Apple's own speech model on iOS 26, with Whisper as the backup, so it's faster and stays offline",
    "An optional account. Echo works fully without one, and your transcripts never leave your iPhone",
    "Summaries, search across everything said, Shortcuts, and the Apple Watch app",
]

struct WhatsNewSheet: View {
    @AppStorage("whats_new_seen_version") private var seenVersion = ""
    @State private var isPresented = false
    @State private var contentHeight: CGFloat = 420

    var body: some View {
        Color.clear
            .onAppear {
                guard !CommandLine.arguments.contains(where: { $0.hasPrefix("UITEST_") }) else { return }
                isPresented = seenVersion != whatsNewVersion
            }
            .sheet(isPresented: $isPresented) {
                // Sized to the text, with a scroll view behind it: the sheet fits its content and never clips at big text sizes.
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("What's New in Echo \(whatsNewVersion)")
                            .font(.echo(22, .bold))
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(whatsNewBullets, id: \.self) { bullet in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Circle().fill(Color.accentColor).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 2 }
                                    Text(bullet).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .font(.echo(17))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        seenVersion = whatsNewVersion
                        isPresented = false
                    } label: {
                        Text("Got it").font(.echo(17, .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                // ponytail: text height plus the button bar (48 + 2 x 16) and some breathing room
                .presentationDetents([.height(contentHeight + 120)])
                .presentationDragIndicator(.visible)
            }
    }
}
