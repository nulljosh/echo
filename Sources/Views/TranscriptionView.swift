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

                    // The word being heard right now is lit in the accent and pops in; speaker names are bold.
                    (Self.styled(leading) + Text(leading.isEmpty || lastWord.isEmpty ? "" : " ") + Self.live(lastWord))
                        .modifier(PopIn(trigger: words.count))
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

    private static func live(_ word: String) -> Text {
        let t = Text(word).foregroundStyle(Color.accentColor).fontWeight(.semibold)
        if #available(iOS 18, macOS 15, *) { return t.customAttribute(LiveWord()) }
        return t
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

@available(iOS 18, macOS 15, *)
private struct LiveWord: TextAttribute {}

/// Draws the live word growing in from 85 percent, faded and soft, with a little spring past full size.
@available(iOS 18, macOS 15, *)
private struct PopRenderer: TextRenderer {
    var progress: Double

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for run in layout.flatMap({ $0 }) {
            guard run[LiveWord.self] != nil, progress != 1 else { ctx.draw(run); continue }
            let box = run.typographicBounds.rect
            var c = ctx
            c.opacity = min(1, max(0, progress))
            if progress < 1 { c.addFilter(.blur(radius: (1 - progress) * 3)) }
            let scale = 0.85 + 0.15 * progress // raw, so the spring's overshoot shows
            c.translateBy(x: box.midX, y: box.midY)
            c.scaleBy(x: scale, y: scale)
            c.translateBy(x: -box.midX, y: -box.midY)
            c.draw(run)
        }
    }
}

// ponytail: redraws every run of the transcript for 0.35 s per new word; draw only the tail if hour-long meetings stutter
private struct PopIn: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *), !reduceMotion {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, p in
                view.textRenderer(PopRenderer(progress: p))
            } keyframes: { _ in
                MoveKeyframe(0.0)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
        } else {
            content
        }
    }
}
