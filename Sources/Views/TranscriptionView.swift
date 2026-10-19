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
            case .error(let msg):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.notate(28))
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.notate(13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let onRetry {
                        Button("Retry", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .padding()
            default:
                // Ready, loading or unloaded all look the same: the app is usable the moment it opens.
                if text.isEmpty {
                    if isRecording {
                        VStack(spacing: 10) {
                            WaveformBarsView(level: audioLevel)
                            Text("Listening...")
                                .font(.notate(14))
                                .foregroundStyle(.secondary)
                        }
                    } else if !placeholder.isEmpty {
                        statusLabel(placeholder)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        // ponytail: split off the trailing word so only it animates in while recording; static text otherwise
                        let words = text.split(separator: " ", omittingEmptySubsequences: true)
                        let lastWord = isRecording ? words.last.map(String.init) ?? "" : ""
                        let leading = isRecording && !lastWord.isEmpty ? words.dropLast().joined(separator: " ") : text

                        // The word being heard right now is highlighted in the accent colour.
                        (Text(leading).foregroundStyle(.primary) + Text(leading.isEmpty || lastWord.isEmpty ? "" : " ")
                            + Text(lastWord).foregroundStyle(Color.accentColor).fontWeight(.semibold))
                            .font(.notate(18, .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .padding(.top, 28)
                            .textSelection(.enabled)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: lastWord)
                            .id(lastWord.isEmpty ? "static" : "live")
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            speech.toggle(id: Self.liveID, text: text, languageCode: unusualLanguage)
                        } label: {
                            Image(systemName: speech.speakingID == Self.liveID ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                .font(.notate(22))
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
                    .font(.notate(12, .medium))
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
            .font(.notate(15))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding()
    }
}
