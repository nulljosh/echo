# Echo — CLAUDE.md

v1.2.0 (build 3). On-device Whisper transcription. iOS 17 + macOS 14. WhisperKit via SPM. Versions live only in `project.yml` (`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`); Info.plists reference `$(...)` — never hardcode them.

## App Store submission state (2026-05-30)
Both targets build clean (Release). `PrivacyInfo.xcprivacy` bundled in both. `ITSAppUsesNonExemptEncryption=false` set. macOS now has `app-sandbox` (required for Mac App Store IAP) — needs a runtime smoke test under sandbox before submitting. See `project_echo_monetization` memory for the App Store Connect checklist.

## Recent Changes (v1.1+)
- Offline-first model loading, cached in UserDefaults
- Live transcription: 2s batches with greedy decoding for speed
- Live buffer capped at 30s (Whisper max)
- Loading state shows placeholder text

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

## Key Components

**TranscriptionEngine** — Loads history, manages WhisperKit model, batches audio every 2s, handles file transcription. Auto-selects model based on device RAM.

**AudioCapture** — AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32. RMS per buffer drives waveform.

**ContentView** — Record/file input, bottom bars (iOS: copy | share | record/file | history; macOS: copy | share | record/file). Cmd+R shortcut on macOS.

**SettingsView** — Model picker (Auto/Tiny/Base/Small), language picker (auto-detect + 11), status indicator.

**WaveformBarsView** — 5 animated bars responding to audio level.

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

- Icons: Swift/NSImage generated (don't use qlmanage)
- `NSLock` guards `audioBuffer` (tap thread ↔ @MainActor)
- macOS drag-drop copies to temp (security scope)
- History: max 50, atomic JSON persistence
- DEVELOPMENT_TEAM: QMM486NPYC
