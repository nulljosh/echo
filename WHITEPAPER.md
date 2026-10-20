# Echo Technical Whitepaper

**v1.4.2** | October 2026

Speech to text that never leaves your device.

Cloud transcription means every recording passes through someone else's
server before it becomes text, which is a bad trade for anything personal.
Echo transcribes on iPhone and Mac. No cloud, no network call. The audio stays
where you recorded it because on-device Whisper models are now good enough that
the privacy cost of a server round-trip buys nothing in return.

## Transcription Pipeline

`TranscriptionEngine` (Services/) is the core. It loads a WhisperKit model
sized to the device's RAM, then batches live audio in 2-second windows and
runs greedy decoding on each batch as it fills, so text appears within
seconds of speaking rather than after the recording ends, because a
transcript that only shows up when you stop talking defeats the point of
live dictation.

- **Live buffer**: capped at 30s (Whisper's practical max window). Only the
  trailing ~8s is re-decoded per 2s tick, not the full rolling buffer, so
  decode time stays flat as a recording grows instead of increasing on every
  tick, which is what a growing recording would otherwise do.
- **Model persistence**: WhisperKit's default cache directory
  (HuggingFace Caches) is purgeable by iOS under storage pressure. After the
  first successful download, Echo copies the model into Application Support,
  which iOS does not purge, so subsequent launches load instantly instead of
  re-downloading a model that can run to hundreds of megabytes.
- **No download wall**: the tiny model ships inside the app (fetched at build
  time by `scripts/fetch-tiny-model.sh`, kept out of git), so the first launch
  is ready in seconds and works offline. The model picked for the device then
  downloads in the background and swaps in only between recordings, never
  mid-sentence. A cached model that fails to load drops back to tiny instead of
  showing an error, and its broken copy is deleted so it can be fetched again.
- **Model selection**: chosen automatically at launch based on available
  device memory. A manual picker is available in Settings > Advanced for users
  who want to trade speed for accuracy or accuracy for speed.
- **Custom words**: names and terms from Settings become Whisper prompt tokens,
  deduplicated and capped at 50 so they guide spelling without crowding out speech.
- **Cleanup**: one tap sends the transcript to Apple's on-device Foundation
  Models to fix punctuation, grammar and filler words. It is only offered where
  the system model exists, and the original is kept if the answer is empty or runs away.

## Structure

```
BundledModels/ tiny Whisper model, fetched at build time, not in git
Sources/
  iOS/        VoxprintApp.swift, Info.plist, Assets.xcassets
  macOS/      VoxprintApp.swift, Info.plist, entitlements, Assets.xcassets
  Models/     TranscriptionEntry (Codable: id, text, date, duration, model)
  Services/   TranscriptionEngine, AudioCapture, Cleanup, SpeechManager
  Views/      ContentView, RecordButton, TranscriptionView, WaveformBarsView,
              HistoryView, SettingsView, SplashView
```

## Platforms

| Platform | Framework | Notes |
|----------|-----------|-------|
| iOS | SwiftUI | iOS 17+, WhisperKit via SPM |
| macOS | SwiftUI | macOS 14+, sandboxed (Mac App Store IAP requirement) |

Versioning lives only in `project.yml` (`MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION`), Info.plists reference it via build variable, never
hardcoded.

## Security / Privacy

All transcription runs on-device via WhisperKit; no audio or text is
transmitted anywhere. `PrivacyInfo.xcprivacy` bundled in both targets.
`ITSAppUsesNonExemptEncryption=false`. macOS target runs under the App
Sandbox.

## License

MIT 2026, Joshua Trommel
