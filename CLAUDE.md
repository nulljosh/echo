# Echo — CLAUDE.md

On-device Whisper transcription. iOS 17 + macOS 14. WhisperKit via SPM.

## Structure

```
Sources/
  iOS/          EchoApp.swift, Info.plist, Assets.xcassets
  macOS/        EchoApp.swift, Info.plist, echo-mac.entitlements, Assets.xcassets
  Models/       TranscriptionEntry (Codable — id, text, date, duration, model)
  Services/     TranscriptionEngine, AudioCapture
  Views/        ContentView, RecordButton, TranscriptionView, HistoryView, ModelPickerView
```

## Key types

**TranscriptionEngine** (`@MainActor ObservableObject`)
- `loadModel()` / `reloadModel()` — initializes WhisperKit, sets `modelState`
- `startRecording()` — starts AudioCapture, launches 4s batch Task
- `stopRecording()` — cancels task, final transcription pass, saves entry
- `transcribeFile(url:)` — security-scoped URL, calls `whisperKit.transcribe(audioPath:)`
- `copyToClipboard()` — `UIPasteboard` on iOS, `NSPasteboard` on macOS
- `[TranscriptionResult].text()` extension deduplicates map/join/trim across both paths

**AudioCapture**
- AVAudioEngine tap at native device sample rate
- AVAudioConverter → 16kHz mono Float32
- Callback: `([Float]) -> Void`

**ContentView**
- `InputMode` enum: `.record` / `.file` — segment control at top
- iOS: `fileImporter` + history sheet
- macOS: `NavigationSplitView` (history sidebar) + `.onDrop` for drag-and-drop audio
- All colors semantic: `systemBackground`, `.primary`, `.secondary`, `.tertiary`, `.regularMaterial`

## Build

```bash
xcodegen generate
open echo.xcodeproj
```

## Targets

- `Echo-iOS` — `com.nulljosh.echo`, iOS 17+
- `Echo-macOS` — `com.nulljosh.echo.mac`, macOS 14+
  - Entitlements: `audio-input`, `network.client`, `files.user-selected.read-only`

## Notes

- WhisperKit downloads models from HuggingFace on first use (~39–500MB depending on model)
- `NSLock` guards `audioBuffer` between AVAudioEngine tap thread and `@MainActor`
- macOS drag-and-drop copies audio to a temp path before transcription (security scope limitation)
- Icons rendered via Swift/NSImage from `icon.svg` at all required sizes
- DEVELOPMENT_TEAM: QMM486NPYC
