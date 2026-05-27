<img src="icon.svg" width="80">

# Echo

![Version](https://img.shields.io/badge/version-1.1.0-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

Native on-device speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Runs entirely locally — no cloud, no API keys, no data leaves the device.

## Features

- Branded splash screen on launch
- Live microphone recording with real-time transcription and waveform feedback
- File transcription — drag and drop on macOS, browse Files on iOS
- 12 languages — auto-detect or force a specific language
- Auto model selection — picks tiny / base / small based on device RAM
- Persistent transcription history (capped at 50 entries)
- Export / share transcriptions natively
- Copy to clipboard
- Retry on model load failure
- Cmd+R keyboard shortcut (macOS)
- Adaptive light/dark mode
- iOS + macOS native SwiftUI

## Architecture

![Architecture](architecture.svg)

`AVAudioEngine` captures mic input at native sample rate. `AVAudioConverter` resamples to 16kHz mono Float32. RMS level is computed per buffer and drives the waveform indicator. `TranscriptionEngine` batches audio every 4 seconds and calls `WhisperKit.transcribe(audioArray:decodeOptions:)` for local CoreML inference. File mode reads actual audio duration via `AVAudioFile` then calls `WhisperKit.transcribe(audioPath:)`. History persists atomically to `Documents/echo-history.json`.

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

Select `Echo-iOS` or `Echo-macOS`. First launch downloads the Whisper model (~39MB tiny, ~150MB base, ~500MB small). Auto mode picks the right size for your device.

## Roadmap

- [ ] Write XCTest suite — unit tests for `TranscriptionEngine`, audio resampling pipeline, history persistence
- [ ] Create Apple Shortcut / Shortcuts workflow that triggers Claude to reload the app
- [ ] UI snapshot tests for waveform indicator and history list

## License

MIT 2026, Joshua Trommel
