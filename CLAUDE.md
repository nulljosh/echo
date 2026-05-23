# Echo — CLAUDE.md

On-device Whisper transcription. iOS 17 + macOS 14. WhisperKit via SPM.

## Structure

```
Sources/
  iOS/          EchoApp.swift, Info.plist, Assets.xcassets
  macOS/        EchoApp.swift, Info.plist, echo-mac.entitlements, Assets.xcassets
  Models/       TranscriptionEntry (Codable — id, text, date, duration, model)
  Services/     TranscriptionEngine, AudioCapture
  Views/        ContentView, RecordButton, TranscriptionView, WaveformBarsView,
                HistoryView, ModelPickerView, SplashView
```

## Key types

**TranscriptionEngine** (`@MainActor ObservableObject`)
- `init()` — loads persisted history from `Documents/echo-history.json`
- `loadModel()` / `reloadModel()` — initializes WhisperKit, sets `modelState`
- `startRecording()` — starts AudioCapture (samples + level callbacks), launches 4s batch loop (transcribe immediately then sleep)
- `stopRecording()` — final pass, saves entry, zeroes audioLevel
- `transcribeFile(url:)` — reads real duration via AVAudioFile, security-scoped URL, `whisperKit.transcribe(audioPath:decodeOptions:)`
- `resolvedModel` — computed; if `selectedModel == "auto"`, picks tiny/base/small based on `ProcessInfo.physicalMemory` (≥8GB=small, ≥4GB=base, else tiny)
- `decodingOptions()` — returns `DecodingOptions(language:)` using `selectedLanguage` ("auto" maps to nil)
- `addEntry` / `saveHistory` — atomic JSON write, history capped at 50
- `[TranscriptionResult].text()` extension deduplicates map/join/trim

**AudioCapture**
- AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32
- `startCapture(onSamples:onLevel:)` — RMS computed per buffer, normalized to 0–1
- `stopCapture()`

**WaveformBarsView**
- 5 animated bars, heights randomized ±0.25 around current `level`
- `.easeInOut(0.1)` animation on each level update

**TranscriptionView**
- `isRecording: Bool` + `audioLevel: Float` — shows WaveformBarsView + "Listening..." when recording and text is empty
- `onRetry: (() -> Void)?` — shows Retry button in `.error` model state

**ContentView**
- `InputMode` enum: `.record` / `.file`
- `retryAction()` — plain function, no closure allocation on render
- `ShareLink` in bottom bar — both platforms
- iOS bottom bar: copy | share | record/file | history
- macOS bottom bar: copy | share | record/file
- Cmd+R shortcut on record button (macOS)
- `static let audioTypes` — avoids UTType alloc per render

**SplashView**
- Shows on cold launch: large waveform icon + "Echo" text
- Fades out after 1.2s with 0.5s ease-out; onDismiss removes from ZStack
- Overlaid in ContentView body via `@State var showSplash = true`

**ModelPickerView**
- Two menus: model (Auto/tiny/base/small) + language (auto + 11 languages)
- "Auto" selects model based on device RAM at load time (see `resolvedModel`)
- Changing model triggers `onReload`; changing language takes effect on next transcription

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

- Icons generated via Swift/NSImage — do not use qlmanage (pads SVG content)
- `NSLock` guards `audioBuffer` between AVAudioEngine tap thread and `@MainActor`
- macOS drag-and-drop copies to temp before transcription (security scope limitation)
- File transcriptions show real duration (AVAudioFile.length / sampleRate)
- History capped at 50, persisted atomically on every insert/delete
- DEVELOPMENT_TEAM: QMM486NPYC
