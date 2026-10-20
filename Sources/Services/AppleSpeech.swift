import AVFoundation
#if canImport(Speech)
import Speech
#endif

/// Apple's own on-device speech model (SpeechAnalyzer, iOS 26 and macOS 26). On Auto it is the first choice for live
/// speech whenever Apple has the language; Whisper covers older systems, custom words and every other language.
enum AppleSpeech {
    static let modelID = "apple"

    /// Whether this OS has SpeechAnalyzer at all (the picker shows the option only then).
    static var isSupported: Bool {
        if #available(iOS 26.0, macOS 26.0, *) { return true }
        return false
    }

    /// The installed locale matching `language` ("auto" means the device language), or nil when none is installed.
    static func installedLocale(for language: String) async -> Locale? {
        #if canImport(Speech)
        if #available(iOS 26.0, macOS 26.0, *) {
            let wanted = language == "auto" ? Locale.current : Locale(identifier: language)
            guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else { return nil }
            let installed = await SpeechTranscriber.installedLocales
            return installed.contains { $0.identifier(.bcp47) == supported.identifier(.bcp47) } ? supported : nil
        }
        #endif
        return nil
    }

    /// Asks the system to install Apple's model for the language in the background. Apple hosts and updates it;
    /// until it lands, Whisper does the work. Safe to call often: an installed model makes this a no-op.
    static func prepare(for language: String) async {
        #if canImport(Speech)
        if #available(iOS 26.0, macOS 26.0, *) {
            let wanted = language == "auto" ? Locale.current : Locale(identifier: language)
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else { return }
            let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
            if let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try? await request.downloadAndInstall()
            }
        }
        #endif
    }

    static func join(_ a: String, _ b: String) -> String {
        a.isEmpty ? b : b.isEmpty ? a : a + " " + b
    }

    /// Transcribes a file into timed lines with Apple's model.
    static func transcribe(url: URL, locale: Locale) async throws -> [TimedLine] {
        #if canImport(Speech)
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

    #if canImport(Speech)
    /// A live recording through SpeechAnalyzer: feed it 16 kHz mono samples, read finished and in-progress text.
    @available(iOS 26.0, macOS 26.0, *)
    final class Live {
        private let transcriber: SpeechTranscriber
        private let analyzer: SpeechAnalyzer
        private let stream: AsyncStream<AnalyzerInput>
        private let input: AsyncStream<AnalyzerInput>.Continuation
        private let source = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        private let format: AVAudioFormat
        private let converter: AVAudioConverter?
        private var results: Task<Void, Error>?
        private(set) var finalText = ""
        private(set) var lines: [TimedLine] = []

        init?(locale: Locale) async {
            transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [.audioTimeRange])
            analyzer = SpeechAnalyzer(modules: [transcriber])
            guard let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { return nil }
            format = best
            converter = best.isEqual(source) ? nil : AVAudioConverter(from: source, to: best)
            (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        }

        /// Starts listening. `onUpdate` gets the finished lines so far and the words still being heard.
        func start(onUpdate: @escaping @MainActor ([TimedLine], String) -> Void) async throws {
            results = Task { [transcriber] in
                var heard = ""
                for try await result in transcriber.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    if result.isFinal {
                        if !text.isEmpty {
                            finalText = AppleSpeech.join(finalText, text)
                            lines.append(TimedLine(start: result.range.start.seconds, end: result.range.end.seconds, text: text, speaker: nil))
                        }
                        heard = ""
                    } else {
                        heard = text
                    }
                    await onUpdate(lines, heard)
                }
            }
            do {
                try await analyzer.start(inputSequence: stream)
            } catch {
                results?.cancel() // nothing will ever arrive; do not leave the listener waiting forever
                throw error
            }
        }

        func feed(_ samples: [Float]) {
            guard !samples.isEmpty,
                  let buffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
            buffer.frameLength = buffer.frameCapacity
            samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
            guard let converter else { input.yield(AnalyzerInput(buffer: buffer)); return }
            let capacity = AVAudioFrameCount(Double(samples.count) * format.sampleRate / source.sampleRate) + 1024
            guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
            var given = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if given { status.pointee = .noDataNow; return nil }
                given = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, out.frameLength > 0 { input.yield(AnalyzerInput(buffer: out)) }
        }

        /// Ends the input and waits for the last words, so `finalText` and `lines` are complete.
        func finish() async {
            input.finish()
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
            _ = try? await results?.value
        }
    }
    #endif
}
