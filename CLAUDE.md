# Echo — CLAUDE.md

v1.3.0. On-device Whisper transcription (speech + music/lyrics). iOS 17 + macOS 14. WhisperKit via SPM. Versions live only in `project.yml` (`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`); Info.plists reference `$(...)` — never hardcode them.

## App Store submission state (2026-05-30)
Both targets build clean (Release). `PrivacyInfo.xcprivacy` bundled in both. `ITSAppUsesNonExemptEncryption=false` set. macOS now has `app-sandbox` (required for Mac App Store IAP) — needs a runtime smoke test under sandbox before submitting. See `project_echo_monetization` memory for the App Store Connect checklist.

## v1.1.0 Changes
- Offline-first model loading: caches `modelFolder` path in UserDefaults after first download; subsequent launches use `WhisperKit(modelFolder:download:false)` — no network needed
- Live transcription interval: 4s → 2s
- Live batches use greedy decoding (`temperature:[0]`, `withoutTimestamps:true`, no prefill) for speed
- Live buffer capped at 30s (Whisper max); final pass on stop uses full buffer + accurate options
- Removed "Loading Whisper model..." from main content area; loading state shows placeholder text

## Structure

```
Sources/
  iOS/          EchoApp.swift, Info.plist, Assets.xcassets
  macOS/        EchoApp.swift, Info.plist, echo-mac.entitlements, Assets.xcassets
  Models/       TranscriptionEntry (Codable — id, text, date, duration, model)
  Services/     TranscriptionEngine, AudioCapture
  Views/        ContentView, RecordButton, TranscriptionView, WaveformBarsView,
                HistoryView, SettingsView, SplashView
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
- Top bar: waveform icon + "Echo" title + status dot + gear button (opens SettingsView sheet)
- `fileDropZone` passes `placeholder: ""` to TranscriptionView to suppress "Press record" text bleed-through

**SplashView**
- Shows on cold launch: large waveform icon + "Echo" text
- Fades out after 1.2s with 0.5s ease-out; onDismiss removes from ZStack
- Overlaid in ContentView body via `@State var showSplash = true`

**SettingsView**
- Sheet with model + language pickers in NavigationStack List layout
- Model rows: Auto (shows resolved name), Tiny, Base, Small — checkmark on selected
- Language rows: Auto-detect + 11 languages — checkmark on selected
- Changing model triggers `onReload` immediately; language takes effect on next transcription
- Status section shows live model state (loading spinner / green dot / error text)

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
