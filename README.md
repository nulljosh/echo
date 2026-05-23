<img src="icon.svg" width="80">

# Echo

![Version](https://img.shields.io/badge/version-1.0.0-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

Native on-device speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Runs entirely locally — no cloud, no API keys, no data leaves the device.

## Features

- Live microphone recording with real-time transcription (4s batch cadence)
- File transcription — drag and drop audio onto macOS, browse Files on iOS
- Model selection: Whisper tiny / base / small (downloads from HuggingFace on first use)
- Transcription history with timestamps and duration
- Copy to clipboard
- Adaptive light/dark mode
- iOS + macOS native SwiftUI (single XcodeGen project)

## Architecture

![Architecture](architecture.svg)

`AVAudioEngine` captures mic input at native sample rate. `AVAudioConverter` resamples to 16kHz mono Float32. `TranscriptionEngine` batches audio every 4 seconds and calls `WhisperKit.transcribe(audioArray:)` for local CoreML inference. File mode calls `WhisperKit.transcribe(audioPath:)` directly. Results are trimmed and written to `@Published transcribedText`.

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

Select `Echo-iOS` (iPhone 17 Pro simulator or device) or `Echo-macOS` (My Mac) and run. First launch downloads the selected Whisper model (~39MB tiny, ~150MB base, ~500MB small).

## License

MIT 2026, Joshua Trommel
