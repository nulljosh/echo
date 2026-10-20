import SwiftUI

struct TranscriptionView: View {
    let text: String
    let modelState: ModelState
    var isRecording: Bool = false
    var audioLevel: Float = 0
    var onRetry: (() -> Void)? = nil
    var unusualLanguage: String? = nil

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
            if case .error(let msg) = modelState {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.echo(34))
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.echo(15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let onRetry {
                        Button("Retry", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                    }
                }
                .padding(20)
            } else if text.isEmpty {
                // Ready, loading or unloaded all look the same: the app is usable the moment it opens.
                if isRecording {
                    VStack(spacing: 12) {
                        WaveformBarsView(level: audioLevel)
                        Text("Listening…").font(.echo(15)).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Press record and start talking")
                        .font(.echo(15))
                        .foregroundStyle(.tertiary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    // ponytail: split off the trailing word so only it is lit while recording
                    let words = text.split(separator: " ", omittingEmptySubsequences: true)
                    let lastWord = isRecording ? words.last.map(String.init) ?? "" : ""
                    let leading = isRecording && !lastWord.isEmpty ? words.dropLast().joined(separator: " ") : text

                    // The word being heard right now is lit in the accent; speaker names are bold.
                    (Self.styled(leading) + Text(leading.isEmpty || lastWord.isEmpty ? "" : " ")
                        + Text(lastWord).foregroundStyle(Color.accentColor).fontWeight(.semibold))
                        .font(.echo(17))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: 680, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)
        .overlay(alignment: .top) {
            if let unusualLanguage {
                Text("Unusual language detected: \(languageLabel(unusualLanguage))")
                    .font(.echo(13, .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: unusualLanguage)
    }

    /// Bolds the "You:" and "Them:" that start meeting lines.
    static func styled(_ text: String) -> Text {
        var out = Text("")
        for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if i > 0 { out = out + Text("\n") }
            if let who = ["You:", "Them:"].first(where: { line.hasPrefix($0) }) {
                out = out + Text(who).fontWeight(.semibold) + Text(line.dropFirst(who.count))
            } else {
                out = out + Text(line)
            }
        }
        return out.foregroundStyle(.primary)
    }
}
