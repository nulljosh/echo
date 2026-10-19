import AVFoundation
#if canImport(Speech) && compiler(>=6.2)
import Speech
#endif

/// Apple's own on-device speech model (SpeechAnalyzer, iOS 26 and macOS 26), as an alternative to Whisper for files.
/// Only used when Apple's model for the language is already on the device: Notate never triggers a download.
enum AppleSpeech {
    static let modelID = "apple"

    /// Whether this OS has (and this build's SDK knows, Swift 6.2 is Xcode 26; older SDKs lack the symbols) SpeechAnalyzer at all (the picker shows the option only then).
    static var isSupported: Bool {
        #if canImport(Speech) && compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) { return true }
        #endif
        return false
    }

    /// The installed locale matching `language` ("auto" means the device language), or nil when none is installed.
    static func installedLocale(for language: String) async -> Locale? {
        #if canImport(Speech) && compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            let wanted = language == "auto" ? Locale.current : Locale(identifier: language)
            guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else { return nil }
            let installed = await SpeechTranscriber.installedLocales
            return installed.contains { $0.identifier(.bcp47) == supported.identifier(.bcp47) } ? supported : nil
        }
        #endif
        return nil
    }

    /// Transcribes a file into timed lines with Apple's model.
    static func transcribe(url: URL, locale: Locale) async throws -> [TimedLine] {
        #if canImport(Speech) && compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            let collect = Task {
                var lines: [TimedLine] = []
                for try await result in transcriber.results where result.isFinal {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { lines.append(TimedLine(start: result.range.start.seconds, end: result.range.end.seconds, text: text, speaker: nil)) }
                }
                return lines
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let file = try AVAudioFile(forReading: url)
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await collect.value
        }
        #endif
        return []
    }
}
