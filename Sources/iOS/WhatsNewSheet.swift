import SwiftUI

private let whatsNewVersion = "2.0"
private let whatsNewBullets = [
    "Summary and action items for any transcript, made on your device",
    "Search everything you've ever said, and export as text, Markdown or subtitles",
    "Shortcuts, Siri and the Action button: start recording or transcribe a file in one tap",
    "An Apple Watch app: record on your wrist, your iPhone writes it out",
]

struct WhatsNewSheet: View {
    @AppStorage("whats_new_seen_version") private var seenVersion = ""
    @State private var isPresented = false
    @State private var contentHeight: CGFloat = 220

    var body: some View {
        Color.clear
            .onAppear {
                guard !CommandLine.arguments.contains(where: { $0.hasPrefix("UITEST_") }) else { return }
                isPresented = seenVersion != whatsNewVersion
            }
            .sheet(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What's New in v\(whatsNewVersion)")
                        .font(.notate(22, .bold))

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(whatsNewBullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Circle().fill(Color.accentColor).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 2 }
                                Text(bullet).lineSpacing(3)
                            }
                        }
                    }
                    .font(.notate(17))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        seenVersion = whatsNewVersion
                        isPresented = false
                    } label: {
                        Text("Got it")
                            .font(.notate(17, .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 8)
                }
                // Measure the ideal height, not the height the sheet squeezes it to, or the detent shrinks and clips the top.
                .fixedSize(horizontal: false, vertical: true)
                // The detent is the content height, so the bottom padding has to clear the home indicator and the sheet's rounded corners too.
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 44)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: SheetHeightKey.self, value: geo.size.height)
                })
                .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
                .presentationDetents([.height(contentHeight)])
            }
    }
}

private struct SheetHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 220
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
