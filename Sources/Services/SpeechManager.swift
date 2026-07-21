import AVFoundation

/// Speaks transcript text aloud on-device via AVSpeechSynthesizer. No network, no deps.
/// ponytail: speak-back is free for all users — Pro gating decision deferred by Joshua, see roadmap.
@MainActor
final class SpeechManager: ObservableObject {
    static let voiceIdentifierKey = "echo.speechVoiceIdentifier"

    @Published private(set) var speakingID: UUID?

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechDelegate()

    init() {
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] in self?.speakingID = nil }
    }

    func toggle(id: UUID, text: String, languageCode: String?) {
        if speakingID == id {
            stop()
            return
        }
        stop()
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        if let identifier = UserDefaults.standard.string(forKey: Self.voiceIdentifierKey),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else if let languageCode, let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }
        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speakingID = nil
    }
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [onFinish] in onFinish?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [onFinish] in onFinish?() }
    }
}
