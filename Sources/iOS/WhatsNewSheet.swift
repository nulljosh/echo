import SwiftUI

private let whatsNewVersion = "1.4.2"
private let whatsNewBullets = [
    "Talk the moment it opens, even offline. A sharper model downloads quietly in the background",
    "Custom words: add names and jargon in Settings and Notate spells them your way",
    "One-tap cleanup fixes punctuation and drops the ums, on device (needs Apple Intelligence)",
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
                VStack(alignment: .leading, spacing: 20) {
                    Text("What's New in v\(whatsNewVersion)")
                        .font(.notate(22, .bold))

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(whatsNewBullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(bullet)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                // The detent is the content height, so the bottom padding has to clear the home indicator and the sheet's rounded corners too.
                .padding(.horizontal, 28)
                .padding(.top, 32)
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
