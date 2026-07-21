import SwiftUI

struct TranscriptionView: View {
    private static let liveID = UUID()

    let text: String
    let modelState: ModelState
    var isRecording: Bool = false
    var audioLevel: Float = 0
    var onRetry: (() -> Void)? = nil
    var placeholder: String = "Press record to start transcribing"
    var unusualLanguage: String? = nil
    @ObservedObject var speech: SpeechManager

    private static let languageNames: [String: String] = [
        "en": "English", "fr": "French", "es": "Spanish", "de": "German",
        "zh": "Chinese", "ja": "Japanese", "ko": "Korean", "ar": "Arabic",
        "pt": "Portuguese", "ru": "Russian", "it": "Italian"
    ]

    private func languageLabel(_ code: String) -> String {
        Self.languageNames[code] ?? Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
    }

    var body: some View {
        Group {
            switch modelState {
            case .unloaded:
                statusLabel("Tap to load model")
            case .loading(let progress):
                VStack(spacing: 12) {
                    if progress >= 1 {
                        ProgressView()
                            .tint(.secondary)
                        Text("Preparing model… first launch can take a few minutes")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if progress > 0 {
                        ProgressView(value: progress)
                            .tint(.secondary)
                            .frame(width: 160)
                        Text("Downloading model… \(Int(progress * 100))%")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .tint(.secondary)
                        Text("Downloading Whisper model...")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
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
                    ScrollView(showsIndicators: false) {
                        Text(text)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .padding(.top, 28)
                            .textSelection(.enabled)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            speech.toggle(id: Self.liveID, text: text, languageCode: unusualLanguage)
                        } label: {
                            Image(systemName: speech.speakingID == Self.liveID ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.easeOut(duration: 0.25), value: modelState)
        .animation(.easeOut(duration: 0.25), value: text.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if let unusualLanguage {
                Text("Unusual language detected: \(languageLabel(unusualLanguage))")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: unusualLanguage)
    }

    private func statusLabel(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding()
    }
}
