import AVFoundation
import Foundation
import WhisperKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Live recording: the mic, the 2 second Whisper batches, meeting labels and the decoding options.
@MainActor
extension TranscriptionEngine {
    /// Feeds audio through the live path 2 s at a time, exactly as the mic would (tests).
    func simulateLive(_ samples: [Float]) async {
        committedText = ""; transcribedText = ""
        bufferLock.withLock { audioBuffer = [] }
        var i = 0
        while i < samples.count {
            let next = min(samples.count, i + 32_000)
            bufferLock.withLock { audioBuffer.append(contentsOf: samples[i..<next]) }
            i = next
            await transcribeCurrentBuffer()
        }
    }

    #if os(macOS)
    /// Feeds a mic stream and a call stream through the meeting mixer 2 s at a time, then stops (tests).
    func simulateMeeting(mic: [Float], call: [Float]) async {
        committedText = ""; transcribedText = ""; lastSpeaker = nil
        bufferLock.withLock { audioBuffer = []; speakerFrames = []; mixer = AudioMixer() }
        var i = 0
        while i < max(mic.count, call.count) {
            let m = i < mic.count ? Array(mic[i..<min(mic.count, i + 32_000)]) : []
            let c = i < call.count ? Array(call[i..<min(call.count, i + 32_000)]) : []
            bufferLock.withLock {
                audioBuffer += mixer.pushMic(m)
                audioBuffer += mixer.pushSystem(c)
                speakerFrames += mixer.takeFrames()
            }
            i += 32_000
            await transcribeCurrentBuffer()
        }
        await transcribeCurrentBuffer(full: true)
    }
    #endif


    func startRecording() {
        // Recording never waits on a model: audio buffers and is transcribed the moment one is ready.
        guard !isRecording else { return }
        if case .error = modelState { return }
        applyPendingUpgrade()
        isRecording = true
        transcribedText = ""
        committedText = ""
        lastSpeaker = nil
        committedLines = []; finalLines = []; bufferOffset = 0
        bufferLock.withLock { audioBuffer = []; speakerFrames = [] }
        recordingStart = Date()

        #if os(macOS)
        let meeting = meetingMode
        bufferLock.withLock { mixer = AudioMixer() }
        if meeting {
            Task {
                do {
                    try await systemCapture.start { [weak self] samples in
                        guard let self else { return }
                        self.bufferLock.withLock {
                            self.audioBuffer.append(contentsOf: self.mixer.pushSystem(samples))
                            self.speakerFrames += self.mixer.takeFrames()
                        }
                    }
                    // Stop was pressed while the capture was still starting: never leave the Mac listening.
                    if !self.isRecording { self.systemCapture.stop() }
                } catch {
                    // No permission yet: keep recording the mic alone rather than failing the recording.
                    await MainActor.run { self.notice = "Allow Echo under Screen and System Audio Recording in System Settings to hear the call." }
                }
            }
        }
        #else
        let meeting = false
        #endif
        do {
            try capture.startCapture(
                onSamples: { [weak self] samples in
                    guard let self else { return }
                    #if os(macOS)
                    if meeting {
                        self.bufferLock.withLock {
                            self.audioBuffer.append(contentsOf: self.mixer.pushMic(samples))
                            self.speakerFrames += self.mixer.takeFrames()
                        }
                        return
                    }
                    #endif
                    self.bufferLock.withLock { self.audioBuffer.append(contentsOf: samples) }
                },
                onLevel: { [weak self] level in
                    DispatchQueue.main.async { self?.audioLevel = level }
                }
            )
        } catch {
            isRecording = false
            #if os(macOS)
            systemCapture.stop()
            #endif
            notice = error.localizedDescription
            return
        }

        appleSession = nil
        recordingTask = Task {
            if await startApple() { await pumpApple(); return }
            while !Task.isCancelled {
                await transcribeCurrentBuffer()
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopRecording() async {
        isRecording = false
        audioLevel = 0
        let live = recordingTask
        recordingTask = nil
        live?.cancel()
        capture.stopCapture()
        #if os(macOS)
        systemCapture.stop()
        #endif
        await live?.value // the live pass in flight finishes first, then the final pass runs alone
        if await !finishApple() {
            // Stopped before any model finished loading: wait for it so nothing said is lost.
            while whisperKit == nil, case .loading = modelState { try? await Task.sleep(for: .milliseconds(200)) }
            await transcribeCurrentBuffer(full: true)
        }

        let duration = Date().timeIntervalSince(recordingStart ?? Date())
        let trimmed = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !CommandLine.arguments.contains("-ECHO_DEMO") { // promo footage never lands in real history
            var entry = TranscriptionEntry(text: trimmed, duration: duration, model: selectedModel)
            entry.lines = finalLines.isEmpty ? nil : finalLines
            addEntry(entry)
        }
        recordingStart = nil
        #if os(iOS)
        if DictationBridge.state == .listening { DictationBridge.publish(trimmed) } // the Echo keyboard asked for this one
        #endif
        applyPendingUpgrade()
    }


    // MARK: - Private

    /// Live: decodes only the audio after the last committed segment, and once that runs past 15 s, commits every
    /// finished segment and moves on. Cost stays flat however long you talk, and nothing said is ever dropped.
    /// Final (`full`): one accurate pass over the whole recording.
    func transcribeCurrentBuffer(full: Bool = false) async {
        // The buffer only ever holds audio after the last committed segment (committed audio is dropped),
        // so memory stays flat however long a meeting runs, and the final pass only decodes the tail.
        let samples: [Float] = bufferLock.withLock {
            Array(audioBuffer.prefix(full ? audioBuffer.count : Self.liveWindowSamples))
        }
        guard samples.count > 16_000 || (full && !samples.isEmpty), let whisperKit else {
            if full, !committedText.isEmpty { transcribedText = committedText }
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: full ? decodingOptions() : liveDecodingOptions())
            if selectedLanguage == "auto", let lang = results.first?.language {
                detectedLanguage = lang
                isUnusualLanguage = !Self.expectedLanguages.contains(lang)
            }
            var segments = results.flatMap(\.segments)
            if full {
                finalLines = committedLines + timedLines(segments, offset: bufferOffset)
                transcribedText = appendLabelled(segments, to: committedText, speaker: &lastSpeaker)
                return
            }
            if samples.count > Self.commitAfterSamples, segments.count > 1 {
                let done = Array(segments.dropLast())
                committedText = appendLabelled(done, to: committedText, speaker: &lastSpeaker)
                committedLines += timedLines(done, offset: bufferOffset)
                let drop = min(samples.count, Int((done.last?.end ?? 0) * 16_000))
                bufferOffset += Double(drop) / 16_000
                bufferLock.withLock {
                    audioBuffer.removeFirst(min(drop, audioBuffer.count))
                    speakerFrames.removeFirst(min(speakerFrames.count, Int((Double(drop) / Double(AudioMixer.frameSamples)).rounded())))
                }
                segments = Array(segments.suffix(1))
            }
            var tailSpeaker = lastSpeaker
            let live = appendLabelled(segments, to: committedText, speaker: &tailSpeaker)
            if !live.isEmpty { transcribedText = live }
        } catch {}
    }

    /// Adds segments to `text`. In meeting mode each segment is labelled You or Them from the loudness frames, and
    /// consecutive lines from the same speaker merge. Outside meeting mode there are no frames and no labels.
    func appendLabelled(_ segments: [TranscriptionSegment], to text: String, speaker: inout String?) -> String {
        let frames = bufferLock.withLock { speakerFrames }
        var out = text
        for seg in segments {
            let words = Self.clean(seg.text)
            guard !words.isEmpty else { continue }
            guard let who = Self.speaker(for: seg, in: frames) else { out = Self.join(out, words); continue }
            if who == speaker { out = Self.join(out, words) } else {
                out += (out.isEmpty ? "" : "\n") + "\(who): " + words
                speaker = who
            }
        }
        return out
    }

    static func speaker(for seg: TranscriptionSegment, in frames: [(mic: Float, system: Float)]) -> String? {
        let lo = min(frames.count, max(0, Int(seg.start * 10))), hi = min(frames.count, max(lo, Int(seg.end * 10)))
        return AudioMixer.speaker(frames[lo..<hi])
    }

    /// Segments as timed lines in recording time (`offset` = seconds dropped before the buffer), for subtitles.
    func timedLines(_ segments: [TranscriptionSegment], offset: Double) -> [TimedLine] {
        let frames = bufferLock.withLock { speakerFrames }
        return segments.compactMap { seg in
            let words = Self.clean(seg.text)
            guard !words.isEmpty else { return nil }
            return TimedLine(start: offset + Double(seg.start), end: offset + Double(seg.end), text: words, speaker: Self.speaker(for: seg, in: frames))
        }
    }



    // Accurate options for final pass and file transcription
    func decodingOptions() -> DecodingOptions {
        var options = DecodingOptions(
            language: selectedLanguage == "auto" ? nil : selectedLanguage,
            concurrentWorkerCount: 4,
            chunkingStrategy: .vad
        )
        options.promptTokens = promptTokens()
        return options
    }

    /// The custom words as Whisper prompt tokens, or nil when there are none.
    func promptTokens() -> [Int]? {
        guard let text = Self.promptText(from: customWords), let tokenizer = whisperKit?.tokenizer else { return nil }
        let tokens = tokenizer.encode(text: text).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        return tokens.isEmpty ? nil : tokens
    }

    /// "Jos, LEC\nEcho" becomes " Jos, LEC, Echo." Trimmed, deduplicated, capped so it never crowds out speech.
    static func promptText(from raw: String) -> String? {
        var seen = Set<String>()
        let words = raw.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(50)
        return words.isEmpty ? nil : " " + words.joined(separator: ", ") + "."
    }

    // Greedy options for live batches, much faster, good enough for preview
    func liveDecodingOptions() -> DecodingOptions {
        DecodingOptions(
            language: selectedLanguage == "auto" ? nil : selectedLanguage,
            temperature: 0,
            usePrefillPrompt: false,
            usePrefillCache: false,
            skipSpecialTokens: true,
            withoutTimestamps: false
        )
    }


    /// Promo footage (`-ECHO_DEMO` launch flag): plays a 16 kHz mono file into the live pipeline in real time, as if
    /// someone were talking into the mic, through the same engine path a recording takes. The commercial's voiceover
    /// is what the app hears, so the screen is real transcription, not a mock.
    func runDemo(_ url: URL) async {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let channel = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        isRecording = true
        transcribedText = ""; committedText = ""; lastSpeaker = nil
        committedLines = []; finalLines = []; bufferOffset = 0
        bufferLock.withLock { audioBuffer = []; speakerFrames = [] }
        recordingStart = Date()
        appleSession = nil
        recordingTask = Task {
            if await startApple() { await pumpApple(); return }
            while !Task.isCancelled {
                await transcribeCurrentBuffer()
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        let chunk = Int(file.processingFormat.sampleRate / 10)
        for start in stride(from: 0, to: samples.count, by: chunk) {
            bufferLock.withLock { audioBuffer.append(contentsOf: samples[start..<min(start + chunk, samples.count)]) }
            audioLevel = min(1, samples[start..<min(start + chunk, samples.count)].map(abs).max() ?? 0)
            try? await Task.sleep(for: .milliseconds(100))
        }
        await stopRecording()
    }
}
