<img src="icon.svg" width="80">

# Echo

![Version](https://img.shields.io/badge/version-1.0.0-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

Native on-device speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Runs entirely locally — no cloud, no API keys, no data leaves the device.

## Features

- Live microphone recording with real-time transcription
- File transcription — drag and drop on macOS, browse Files on iOS
- Model selection: Whisper tiny / base / small
- Persistent transcription history across launches
- Copy to clipboard
- Retry on model load failure
- Cmd+R keyboard shortcut (macOS)
- Adaptive light/dark mode
- iOS + macOS native SwiftUI

## Architecture

![Architecture](architecture.svg)

`AVAudioEngine` captures mic input at the native sample rate. `AVAudioConverter` resamples to 16kHz mono Float32. `TranscriptionEngine` batches audio every 4 seconds and calls `WhisperKit.transcribe(audioArray:)` for local CoreML inference. File mode calls `WhisperKit.transcribe(audioPath:)` directly. History persists to `Documents/echo-history.json`.

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

Select `Echo-iOS` or `Echo-macOS`. First launch downloads the Whisper model (~39MB tiny, ~150MB base, ~500MB small).

## License

MIT 2026, Joshua Trommel
