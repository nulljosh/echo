#if os(macOS)
import AVFoundation
import ScreenCaptureKit

/// Hears what the Mac plays, so a call on Zoom, Meet, Teams or FaceTime is transcribed along with your mic.
/// ScreenCaptureKit, on device, no bot joins the call. macOS asks for Screen and System Audio Recording the first time.
final class SystemAudioCapture: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    private var onSamples: (([Float]) -> Void)?
    private var converter: AVAudioConverter?
    private let queue = DispatchQueue(label: "notate.system-audio")
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    func start(onSamples: @escaping ([Float]) -> Void) async throws {
        stop()
        self.onSamples = onSamples
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else { throw AudioCaptureError.formatUnavailable }
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // never hear Notate's own speak-back
        config.sampleRate = 48_000
        config.channelCount = 1
        // Video is required but unused: keep it tiny and slow.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        stream?.stopCapture { _ in }
        stream = nil
        onSamples = nil
        converter = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid,
              let desc = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              let format = AVAudioFormat(standardFormatWithSampleRate: desc.mSampleRate, channels: desc.mChannelsPerFrame) else { return }
        try? sampleBuffer.withAudioBufferList { list, _ in
            guard let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list.unsafePointer) else { return }
            if converter == nil || converter?.inputFormat != format { converter = AVAudioConverter(from: format, to: target) }
            guard let converter else { return }
            let samples = AudioCapture.convert(pcm, with: converter, to: target)
            if !samples.isEmpty { onSamples?(samples) }
        }
    }
}
#endif
