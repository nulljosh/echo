import AVFoundation

class AudioCapture {
    private var engine: AVAudioEngine?
    private var onSamples: (([Float]) -> Void)?

    func startCapture(onSamples: @escaping ([Float]) -> Void) throws {
        stopCapture()
        self.onSamples = onSamples

        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

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
            self?.convert(buffer: buffer, from: inputFormat, to: targetFormat, using: converter)
        }

        engine.prepare()
        try engine.start()
    }

    func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        onSamples = nil
    }

    private func convert(
        buffer: AVAudioPCMBuffer,
        from inputFormat: AVAudioFormat,
        to targetFormat: AVAudioFormat,
        using converter: AVAudioConverter
    ) {
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard frameCapacity > 0,
              let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }

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

        guard status != .error,
              outBuffer.frameLength > 0,
              let channelData = outBuffer.floatChannelData else { return }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(outBuffer.frameLength)))
        onSamples?(samples)
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case formatUnavailable
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .formatUnavailable: return "Could not create 16kHz audio format."
        case .converterUnavailable: return "Could not create audio converter."
        }
    }
}
