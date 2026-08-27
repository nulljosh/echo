# Voxprint Technical Whitepaper

**v1.3.7** | August 2026

Voxprint is on-device speech transcription for iOS and macOS. No cloud, no
network calls for transcription — audio never leaves the device.

## Transcription Pipeline

`TranscriptionEngine` (Services/) is the core. It loads a WhisperKit model
sized to the device's RAM, then batches live audio in 2-second windows and
runs greedy decoding on each batch as it fills, so text appears within
seconds of speaking rather than after the recording ends.

- **Live buffer**: capped at 30s (Whisper's practical max window). Only the
  trailing ~8s is re-decoded per 2s tick, not the full rolling buffer, so
  decode time stays flat as a recording grows instead of increasing on every
  tick.
- **Model persistence**: WhisperKit's default cache directory
  (HuggingFace Caches) is purgeable by iOS under storage pressure. After the
  first successful download, Voxprint copies the model into Application Support,
  which iOS does not purge, so subsequent launches load instantly instead of
  re-downloading.
- **Model selection**: chosen automatically at launch based on available
  device memory — no user-facing model picker.

## Structure

```
Sources/
  iOS/        EchoApp.swift, Info.plist, Assets.xcassets
  macOS/      EchoApp.swift, Info.plist, entitlements, Assets.xcassets
  Models/     TranscriptionEntry (Codable: id, text, date, duration, model)
  Services/   TranscriptionEngine, AudioCapture
  Views/      ContentView, RecordButton, TranscriptionView, WaveformBarsView,
              HistoryView, SettingsView, SplashView
```

## Platforms

| Platform | Framework | Notes |
|----------|-----------|-------|
| iOS | SwiftUI | iOS 17+, WhisperKit via SPM |
| macOS | SwiftUI | macOS 14+, sandboxed (Mac App Store IAP requirement) |

Versioning lives only in `project.yml` (`MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION`) — Info.plists reference it via build variable, never
hardcoded.

## Security / Privacy

All transcription runs on-device via WhisperKit; no audio or text is
transmitted anywhere. `PrivacyInfo.xcprivacy` bundled in both targets.
`ITSAppUsesNonExemptEncryption=false`. macOS target runs under the App
Sandbox.

## License

MIT 2026, Joshua Trommel
