<img src="icon.svg" width="80">

# Echo

![Version](https://img.shields.io/badge/version-1.0.0-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green)

Native on-device speech transcription using [WhisperKit](https://github.com/argmaxinc/WhisperKit). Runs entirely locally — no cloud, no API keys, no internet required after model download.

## Features

- Real-time transcription via Whisper AI (CoreML + Neural Engine)
- Model selection: tiny / base / small
- Transcription history with timestamps and duration
- Copy to clipboard
- iOS + macOS native SwiftUI

## Architecture

![Architecture](architecture.svg)

AVAudioEngine captures microphone input, converts to 16kHz mono Float32, and batches audio every 4 seconds to WhisperKit for local inference.

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

Select `Echo-iOS` or `Echo-macOS` target and run.

## License

MIT 2026, Joshua Trommel
