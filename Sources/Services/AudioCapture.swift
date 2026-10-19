import AVFoundation

class AudioCapture {
    private var engine: AVAudioEngine?
    private var onSamples: (([Float]) -> Void)?
    private var onLevel: ((Float) -> Void)?

    func startCapture(onSamples: @escaping ([Float]) -> Void, onLevel: @escaping (Float) -> Void) throws {
        stopCapture()
        self.onSamples = onSamples
        self.onLevel = onLevel

        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // No input device (a Mac mini with nothing plugged in): installTap would raise an exception Swift can't catch.
        // The node's output format still claims 44.1 kHz stereo with no device; the hardware format is the truth.
        let hardware = inputNode.inputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
            self.engine = nil
            throw AudioCaptureError.noMicrophone
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer, inputFormat: inputFormat, targetFormat: targetFormat, converter: converter)
        }

        engine.prepare()
        try engine.start()
    }

    func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        onSamples = nil
        onLevel = nil
    }

    private func process(
        buffer: AVAudioPCMBuffer,
        inputFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter
    ) {
        let samples = Self.convert(buffer, with: converter, to: targetFormat)
        guard !samples.isEmpty else { return }

        // RMS of typical speech sits well under 1.0, so scale it up (tuned by ear) before
        // clamping so the waveform view actually swings across its full range.
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        onLevel?(min(rms * 15, 1.0))
        onSamples?(samples)
    }

    /// Resamples one buffer to the 16 kHz mono floats Whisper wants. Shared with the system audio capture.
    static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to targetFormat: AVAudioFormat) -> [Float] {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard frameCapacity > 0,
              let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return [] }

        // AVAudioConverter pulls input via this callback rather than taking a buffer directly.
        // We only have the one buffer to offer, so hand it over once and tell the converter
        // there's nothing more this round on every call after.
        var inputConsumed = false
        let status = converter.convert(to: outBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return buffer
        }

        guard status != .error, outBuffer.frameLength > 0, let channelData = outBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(outBuffer.frameLength)))
    }
}

/// Lines up two 16 kHz streams (your mic and the call) and sums them into one. A stream that stalls or goes
/// quiet never holds the other back: once one runs more than half a second ahead, the other is padded with silence.
struct AudioMixer {
    private(set) var mic: [Float] = []
    private(set) var system: [Float] = []
    static let maxLag = 8_000
    /// One loudness pair per 100 ms of mixed audio (mic, call), so each transcript segment can be labelled You or Them.
    private(set) var frames: [(mic: Float, system: Float)] = []
    static let frameSamples = 1_600
    private var micSquares: Float = 0, systemSquares: Float = 0, frameFill = 0

    mutating func pushMic(_ samples: [Float]) -> [Float] { mic += samples; return drain() }
    mutating func pushSystem(_ samples: [Float]) -> [Float] { system += samples; return drain() }

    /// Hands over the loudness frames measured so far.
    mutating func takeFrames() -> [(mic: Float, system: Float)] { defer { frames = [] }; return frames }

    private mutating func drain() -> [Float] {
        if mic.count > system.count + Self.maxLag { system += [Float](repeating: 0, count: mic.count - system.count) }
        if system.count > mic.count + Self.maxLag { mic += [Float](repeating: 0, count: system.count - mic.count) }
        let n = min(mic.count, system.count)
        guard n > 0 else { return [] }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            out[i] = max(-1, min(1, mic[i] + system[i]))
            micSquares += mic[i] * mic[i]
            systemSquares += system[i] * system[i]
            frameFill += 1
            if frameFill == Self.frameSamples {
                frames.append((sqrt(micSquares / Float(frameFill)), sqrt(systemSquares / Float(frameFill))))
                micSquares = 0; systemSquares = 0; frameFill = 0
            }
        }
        mic.removeFirst(n)
        system.removeFirst(n)
        return out
    }

    /// "You" when the mic carries the voice, "Them" when the call does. The mic also hears the call through the
    /// speakers, so the call wins once it is above the floor and at least two thirds as loud as the mic.
    // ponytail: energy heuristic, tune callFloor/callBias on real calls; diarization model if it misfires
    static let callFloor: Float = 0.004
    static let callBias: Float = 1.5
    static func speaker(_ frames: ArraySlice<(mic: Float, system: Float)>) -> String? {
        guard !frames.isEmpty else { return nil }
        let mic = frames.reduce(0) { $0 + $1.mic }, call = frames.reduce(0) { $0 + $1.system }
        let n = Float(frames.count)
        return call / n > callFloor && call * callBias >= mic ? "Them" : "You"
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case formatUnavailable
    case converterUnavailable
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .formatUnavailable: return "Could not create 16kHz audio format."
        case .converterUnavailable: return "Could not create audio converter."
        case .noMicrophone: return "No microphone found. Plug one in or pick one in System Settings, Sound, Input."
        }
    }
}
