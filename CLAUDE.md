# Echo — CLAUDE.md

v1.3.0 (build 4). On-device Whisper transcription. iOS 17 + macOS 14. WhisperKit via SPM. Versions live only in `project.yml` (`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`); Info.plists reference `$(...)` — never hardcode them.

## App Store submission state (2026-05-30)
Both targets build clean (Release). `PrivacyInfo.xcprivacy` bundled in both. `ITSAppUsesNonExemptEncryption=false` set. macOS now has `app-sandbox` (required for Mac App Store IAP) — needs a runtime smoke test under sandbox before submitting. See `project_echo_monetization` memory for the App Store Connect checklist.

## Open design question (2026-06-20)
A task note asked whether to switch the whole app to the clrs.cc color palette (and use it as the design system across all apps, not just Echo) — that's a cross-repo design decision, not applied. Settings icon made more obvious (`gearshape.fill`, larger, `.primary`) and transcript view's scroll indicators/bounce tuned down per the same note; both verified via `xcodebuild build -scheme Echo-macOS` (BUILD SUCCEEDED).

## Recent Changes (v1.3.0)
- Fixed model-folder cache actually being used in `loadModel()` (was dead code — every launch re-resolved via HuggingFace)
- Live transcription now only re-decodes a trailing ~8s window instead of the full rolling 30s buffer every 2s tick (was getting slower as recordings got longer)
- App icon redone as a full-bleed opaque PNG (old one had alpha transparency, causing a white halo behind the icon on iOS)

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

## Imported from echo.pdf (2026-06-21)
- [x] Mac screenshots — fixed and verified during this pass (Screen Recording permission granted, `fastlane mac_screenshots` now captures the real app window).
- [ ] Push IPA/upload to TestFlight via `fastlane beta`/`mac_beta` — go-ahead given, not yet run.
- [ ] Watch companion app — net-new watchOS target, not started.
