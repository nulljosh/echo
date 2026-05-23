# Echo — CLAUDE.md

On-device Whisper transcription app. iOS + macOS. WhisperKit via SPM.

## Structure

- `Sources/iOS/` — iOS app entry point + assets
- `Sources/macOS/` — macOS app entry point + assets + entitlements
- `Sources/Models/` — TranscriptionEntry (Codable)
- `Sources/Services/` — TranscriptionEngine (@MainActor), AudioCapture (AVAudioEngine)
- `Sources/Views/` — ContentView, RecordButton, TranscriptionView, HistoryView, ModelPickerView

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

## Key Notes

- WhisperKit downloads models from HuggingFace on first run (~150MB for base)
- Audio tap runs at native device sample rate, converted to 16kHz via AVAudioConverter
- Transcription happens in 4-second batches while recording
- macOS entitlements: `audio-input` + `network.client` (no full sandbox)
- DEVELOPMENT_TEAM: QMM486NPYC

## Targets

- `Echo-iOS`: `com.nulljosh.echo`, iOS 17+
- `Echo-macOS`: `com.nulljosh.echo.mac`, macOS 14+
