<img src="icon.svg" width="80">

# Echo

![Version](https://img.shields.io/badge/version-1.1.0-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

Native on-device speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Runs entirely locally — no cloud, no API keys, no data leaves the device.

## Features

- Live microphone recording with real-time transcription and waveform
- File transcription — drag/drop on macOS, browse on iOS
- 12 languages — auto-detect or force specific
- Auto model selection based on device RAM
- Persistent history (max 50 entries)
- Export / share / copy to clipboard
- Retry on model load failure
- Cmd+R shortcut (macOS)
- Light/dark mode
- iOS + macOS SwiftUI

## Architecture

![Architecture](architecture.svg)

`AVAudioEngine` captures mic at native sample rate, resampled to 16kHz mono Float32. Waveform driven by RMS per buffer. Batches transcribe every 2 seconds via `WhisperKit` CoreML inference. File mode uses `AVAudioFile` for duration. History (max 50) persists to `Documents/echo-history.json`.

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

Select `Echo-iOS` or `Echo-macOS`. First launch downloads the Whisper model (~39MB tiny, ~150MB base, ~500MB small). Auto mode picks the right size for your device.

## Roadmap

XCTest suite, snapshot tests, Apple Shortcut integration.

## License

MIT 2026, Joshua Trommel
