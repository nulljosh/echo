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
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Loading Whisper model...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            case .error(let msg):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
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
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statusLabel(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .padding()
    }
}
