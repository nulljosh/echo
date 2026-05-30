import SwiftUI

struct PaywallView: View {
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let perks: [(String, String)] = [
        ("doc.fill", "Transcribe audio files without limits"),
        ("waveform", "Small model, the most accurate transcription"),
        ("lock.shield", "Stays on device. No account, no cloud, no tracking"),
        ("infinity", "One payment. No subscription, ever")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.bottom, 16)

            Text("Echo Pro")
                .font(.system(size: 28, weight: .bold))
            Text("Own it once. Not a subscription.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(perks, id: \.1) { icon, label in
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 24)
                        Text(label)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 32)

            Spacer(minLength: 0)

            Button(action: { Task { await store.purchase() } }) {
                Group {
                    if store.purchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buyTitle).font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(store.purchasing || store.product == nil)
            .padding(.horizontal, 24)

            Button("Restore Purchase") { Task { await store.restore() } }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            Button("Not now") { dismiss() }
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: 420)
        .onChange(of: store.isPro) { _, isPro in if isPro { dismiss() } }
    }

    private var buyTitle: String {
        if let price = store.product?.displayPrice { return "Unlock for \(price)" }
        return "Unlock Echo Pro"
    }
}
