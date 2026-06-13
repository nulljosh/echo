import SwiftUI

struct TranscriptionView: View {
    let text: String
    let modelState: ModelState
    var isRecording: Bool = false
    var audioLevel: Float = 0
    var onRetry: (() -> Void)? = nil
    var placeholder: String = "Press record to start transcribing"

    var body: some View {
        Group {
            switch modelState {
            case .unloaded:
                statusLabel("Tap to load model")
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.secondary)
                    Text(placeholder.isEmpty ? "Downloading Whisper model..." : placeholder)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            case .error(let msg):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let onRetry {
                        Button("Retry", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .padding()
            case .ready:
                if text.isEmpty {
                    if isRecording {
                        VStack(spacing: 10) {
                            WaveformBarsView(level: audioLevel)
                            Text("Listening...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    } else if !placeholder.isEmpty {
                        statusLabel(placeholder)
                    }
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
