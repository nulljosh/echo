import AVFoundation
import Foundation
import WhisperKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Apple first: SpeechAnalyzer runs the recording when it fits, Whisper otherwise.
@MainActor
extension TranscriptionEngine {
    /// Starts Apple's live model when it fits: Auto or Apple picked, iOS or macOS 26, Apple has the language installed,
    /// no meeting (Whisper labels You and Them) and no custom words (Apple's live model has no prompt to steer it).
    func startApple() async -> Bool {
        #if canImport(Speech)
        #if os(macOS)
        let meeting = meetingMode
        #else
        let meeting = false
        #endif
        guard #available(iOS 26.0, macOS 26.0, *),
              Self.appleFits(model: selectedModel, meeting: meeting, customWords: customWords),
              let locale = await AppleSpeech.installedLocale(for: selectedLanguage),
              let live = await AppleSpeech.Live(locale: locale) else { return false }
        do {
            try await live.start { [weak self] text in
                guard let self, self.isRecording else { return }
                self.transcribedText = text
            }
        } catch {
            return false // Whisper takes over with everything buffered so far
        }
        appleSession = live
        return true
        #else
        return false
        #endif
    }

    /// Whether a recording may run on Apple: Auto or Apple picked, not a meeting, no custom words.
    static func appleFits(model: String, meeting: Bool, customWords: String) -> Bool {
        (model == "auto" || model == AppleSpeech.modelID) && !meeting && promptText(from: customWords) == nil
    }

    /// Test hook: one recording through Apple first with these samples, stopped after `listen` (zero stops it while
    /// the Apple session is still starting). True when Apple handled it; false means Whisper would have.
    func simulateAppleLive(_ samples: [Float], listen: Duration = .milliseconds(600)) async -> Bool {
        transcribedText = ""; finalLines = []
        bufferLock.withLock { audioBuffer = samples }
        isRecording = true
        let run = Task { () -> Bool in
            guard await startApple() else { return false }
            await pumpApple()
            return true
        }
        if listen > .zero { try? await Task.sleep(for: listen) }
        run.cancel()
        let started = await run.value
        isRecording = false
        return await finishApple() && started
    }

    /// Hands the mic audio to Apple's model every 200 ms. The buffer is drained as it goes.
    func pumpApple() async {
        #if canImport(Speech)
        guard #available(iOS 26.0, macOS 26.0, *), let live = appleSession as? AppleSpeech.Live else { return }
        while !Task.isCancelled {
            live.feed(bufferLock.withLock { () -> [Float] in
                let chunk = audioBuffer
                audioBuffer.removeAll(keepingCapacity: true)
                return chunk
            })
            try? await Task.sleep(for: .milliseconds(200))
        }
        #endif
    }

    /// Feeds the last audio, waits for the final words and keeps them. False when this recording ran on Whisper.
    func finishApple() async -> Bool {
        #if canImport(Speech)
        guard #available(iOS 26.0, macOS 26.0, *), let live = appleSession as? AppleSpeech.Live else { return false }
        appleSession = nil
        live.feed(bufferLock.withLock { () -> [Float] in
            let rest = audioBuffer
            audioBuffer = []
            return rest
        })
        await live.finish()
        transcribedText = live.finalText
        finalLines = live.lines
        return true
        #else
        return false
        #endif
    }

}
