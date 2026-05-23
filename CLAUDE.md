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
- `init()` — loads persisted history from `Documents/echo-history.json`
- `loadModel()` / `reloadModel()` — initializes WhisperKit, sets `modelState`
- `startRecording()` — starts AudioCapture, launches 4s batch loop (transcribes immediately then sleeps)
- `stopRecording()` — cancels task, final pass, saves entry + persists
- `transcribeFile(url:)` — security-scoped URL, `whisperKit.transcribe(audioPath:)`
- `copyToClipboard()` — `UIPasteboard` on iOS, `NSPasteboard` on macOS
- `saveHistory()` — atomic write of `[TranscriptionEntry]` JSON to Documents
- `[TranscriptionResult].text()` extension deduplicates map/join/trim

**AudioCapture**
- AVAudioEngine tap at native sample rate → AVAudioConverter → 16kHz mono Float32
- `startCapture(onSamples:)` / `stopCapture()`

**ContentView**
- `InputMode` enum: `.record` / `.file` — segment control
- iOS: `fileImporter` + history sheet; macOS: `NavigationSplitView` + `.onDrop`
- Cmd+R keyboard shortcut (macOS) on record button
- `TranscriptionView(onRetry:)` — shows retry button on `.error` model state
- `static let audioTypes` — avoids recreating UTType array on each render
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

- Icons generated via `/tmp/render_icon.swift` (Swift/NSImage) — qlmanage pads SVG, don't use it for icons
- `NSLock` guards `audioBuffer` between AVAudioEngine tap thread and `@MainActor`
- macOS drag-and-drop copies to temp before transcription (security scope limitation)
- DEVELOPMENT_TEAM: QMM486NPYC

## Next steps

- Language picker (WhisperKit `DecodingOptions(language:)`)
- Live waveform — RMS from buffer tap, animate bars
- Export / share sheet — `.shareLink` on `.txt`
- Timestamp segments — `TranscriptionSegment` start/end times
- iCloud sync — `NSUbiquitousKeyValueStore` or CloudKit
- Menu bar quick-record (macOS) — `MenuBarExtra` scene
