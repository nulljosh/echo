import SwiftUI

struct TranscriptionView: View {
    let text: String
    let modelState: ModelState

    var body: some View {
        Group {
            switch modelState {
            case .unloaded:
                statusLabel("Tap to load model")
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Whisper model...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            case .error(let msg):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            case .ready:
                if text.isEmpty {
                    statusLabel("Press record to start transcribing")
                } else {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func statusLabel(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding()
    }
}
