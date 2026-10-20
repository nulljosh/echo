# Architecture

Echo turns speech into text without any of it leaving the device. Record straight from the mic or drop in an audio file, and the words appear as it listens, updated live rather than dumped all at once at the end.

WhisperKit does the actual listening, running the model on the phone or Mac itself. There is no server call, so it works with no network connection, and the model downloads once and stays put for next time.

## How it runs

You tap record. `AudioCapture.swift` listens to the mic and hands the sound over in the shape the model wants. `TranscriptionEngine.swift` reads the last eight seconds every couple of seconds and updates the words on screen, so a long recording stays as fast as a short one. When you stop, it goes over the whole recording once more for the final text.

The model is picked for you by how much memory the device has. Small on newer phones and Macs, Base or Tiny on older ones. You can override it in Settings, up to the large Turbo model.

The model downloads once. It lands in a folder iOS is allowed to empty, so the engine copies it somewhere safe. If that copy is ever broken or half finished, the engine deletes every copy and downloads a clean one. That exact failure bricked 1.3.9, and `Tests/ModelRecoveryTests.swift` now breaks a model on purpose and checks the app heals and transcribes real speech.

`ContentView.swift` is the whole screen on both iPhone and Mac: record or pick a file, the live transcript, then copy, share and history. `SpeechManager.swift` reads a transcript back out loud. History keeps the last 50. Everything is free, there is no Pro tier.

## Files

| File | What it owns |
|---|---|
| `Sources/iOS/VoxprintApp.swift` | iOS app entry: window group, splash overlay, all-targets entry |
| `Sources/macOS/VoxprintApp.swift` | macOS app entry: window group with 1280x800 min size |
| `Sources/Models/TranscriptionEntry.swift` | Codable entry: id, text, date, duration (seconds), model name |
| `Sources/Services/TranscriptionEngine.swift` | WhisperKit model management: download/cache/load, transcribe, live update, language detection, model auto-selection by RAM |
| `Sources/Services/AudioCapture.swift` | AVAudioEngine tap: converts to 16kHz mono Float32, computes RMS for waveform, thread-safe via NSLock |
| `Sources/Views/ContentView.swift` | Main UI: record button, file drop (macOS), transcript display, action bar (copy/share/history), live waveform, settings icon (iOS) or gear (macOS) |
| `Sources/Views/RecordButton.swift` | Record/Stop button with state feedback |
| `Sources/Views/TranscriptionView.swift` | Live transcript display with language detection badge |
| `Sources/Views/WaveformBarsView.swift` | 5 animated bars responding to audio RMS in real-time |
| `Sources/Views/HistoryView.swift` | Past transcriptions: list, delete, share entry |
| `Sources/Services/SpeechManager.swift` | Reads a transcript aloud with the system voice, on device |
| `Sources/Views/SettingsView.swift` | Model picker (Auto/Tiny/Base/Small/Large Turbo), language picker (auto plus every language Whisper knows), status indicator |
| `Sources/Views/SplashView.swift` | Launch splash overlay |
| `Sources/iOS/WhatsNewSheet.swift` | One-time What's New sheet per version |
| `Sources/iOS/Assets.xcassets/` | AppIcon (opaque PNG, no alpha; iOS 17+) |
| `Sources/macOS/Assets.xcassets/` | AppIcon set (16/32/64/128/256/512/1024, opaque, rounded corners baked in; macOS 14+) |
| `Sources/macOS/voxprint-mac.entitlements` | Sandbox entitlements: audio-input, network.client, files.user-selected.read-only |
| `project.yml` | XcodeGen: iOS/macOS targets, shared source tree, versions from MARKETING_VERSION/CURRENT_PROJECT_VERSION |
| `PrivacyInfo.xcprivacy` | Privacy manifest (bundled in both targets) |
| `watchos/` | watchOS companion app: records voice memos on the watch and plays them back |
| `watchos/VoxprintWatchApp.swift` | watchOS app entry point with window group |
| `watchos/ContentView.swift` | Main watchOS view: record screen and history |
| `watchos/Models/` | `RecordingEntry` and `RecordingStore`: records `.m4a` files with `AVAudioRecorder`, lists and plays them |
| `watchos/Views/` | Record view, history list, waveform bars |
| `watchos/Assets.xcassets/` | watchOS app icon and assets |
| `docs/index.html` | Redirects to app.html (kept for backward compatibility) |
| `docs/app.html` | Landing page: responsive hero, features list, app store links, install instructions, inline navigation and settings |
| `docs/styles.css` | Landing page styling: light/dark mode via prefers-color-scheme, responsive grid, device-frame screenshots |
| `docs/script.js` | Landing page interactivity: theme toggle, settings modal, feature carousel, smooth scrolling |
| `docs/devices.css` | Device frame styling for landing page demo screenshots (iPhone, Mac frames) |
| `docs/privacy.html` | Privacy policy page: static content, linked from landing footer |
| `UITests/PreviewScreenshot.swift` | Snapshot test suite: captures App Store screenshots in multiple locales and configurations |
| `UITests/SnapshotHelper.swift` | Fastlane snapshot helper: integrates with Xcode testing framework to generate screenshots |
| `UITests-mac/MacScreenshot.swift` | macOS App Store screenshot capture via UI automation |
| `Tests/TranscriptionEntryTests.swift` | Unit tests for TranscriptionEntry model (Codable, persistence) |
| `Tests/ModelRecoveryTests.swift` | Opt-in end-to-end QA: corrupts the model folder, checks the engine heals, then transcribes real speech |
| `scripts/update_screenshots.sh` | Runs snapshot tests and stages generated screenshots for App Store upload |
| `ci_scripts/ci_post_clone.sh` | Xcode Cloud setup script: installs/runs xcodegen before building to regenerate xcodeproj from project.yml |

## Storage

- **UserDefaults**: settings (model, language, microphone permission), transcription history (max 50, atomic JSON)
- **Application Support**: WhisperKit models (persistent, survives iOS cache purge)
- **Caches**: initial HuggingFace download (transient, iOS can purge, triggers re-download and copy to Application Support)

## Audio pipeline

`AudioCapture` taps the input bus of AVAudioEngine at 44.1kHz, converts to 16kHz mono Float32 via AVAudioConverter, computes RMS per buffer for waveform visualization. Audio is buffered and passed to `TranscriptionEngine.transcribe()` in 2-second batches.

## Transcription pipeline

WhisperKit max buffer is 30 seconds. Live transcription only processes a trailing ~8s window (not the full rolling 30s) to avoid slowdown as recordings grow longer. Batches are greedy-decoded (fastest, not most-accurate) to keep UI responsive. Language detection reads `DecodingResult.language` and `languageProbs` off the same call (no extra network).

## App Store gotchas

- Icon must be fully opaque (no alpha channel). Flatten with `magick icon.png -background '#0074D9' -alpha remove -alpha off PNG24:icon.png`.
- macOS icon needs separate 1024x1024 entry in Assets (universal 1024 alone is insufficient).
- `ITSAppUsesNonExemptEncryption=false` required in Info.plist to avoid manual ASC build-option confirmation on every upload.
- Screenshot display type is `APP_IPHONE_65` for 1284x2778 (not `IPHONE_67`).
- Versions live in `project.yml` only (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`); Info.plists reference these via `$(...)`, never hardcode.

## Gotchas

- Model download goes to Caches (iOS can purge). Copy to Application Support on first download for persistence.
- Live transcription window at ~8s is calibrated for Whisper's 30s max and current device speeds. Recalibrate if models change or hardware baseline shifts.
