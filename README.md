<img src="icon.svg" width="80" style="border-radius:18px">

# Voxprint

![Version](https://img.shields.io/badge/version-1.3.3-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2017%20%7C%20macOS%2014-lightgrey) ![License](https://img.shields.io/badge/license-MIT-green) [![GitHub](https://img.shields.io/badge/GitHub-nulljosh%2Fvoxprint-black?logo=github)](https://github.com/nulljosh/voxprint)

Speech to text that never leaves your device.

Native transcription on iPhone and Mac with [WhisperKit](https://github.com/argmaxinc/WhisperKit). No cloud. No API keys. Nothing uploaded, ever.

Live at [voxprint.heyitsmejosh.com](https://voxprint.heyitsmejosh.com) · [App Store](https://apps.apple.com/app/id6782604262)

<p align="center">
  <img src="screenshots/appstore/1-finished-transcript.png" width="180">
  <img src="screenshots/appstore/2-history.png" width="180">
  <img src="screenshots/appstore/3-paywall.png" width="180">
  <img src="screenshots/appstore/4-settings.png" width="180">
  <img src="screenshots/appstore/5-live-recording.png" width="180">
</p>

## Features

- Record live. Text and waveform appear as you talk
- Transcribe a file. Drag it in on Mac, browse on iOS
- 12 languages. Auto-detect, or pick one
- Picks the right model for your device's RAM
- History, the last 50
- Export, share, copy
- Retries if the model fails to load
- Cmd+R on Mac
- Light and dark
- SwiftUI on iOS and macOS

## Architecture

![Architecture](architecture.svg)

`AVAudioEngine` captures the mic at native rate and resamples to 16 kHz mono Float32. The waveform is RMS per buffer. Every 2 seconds a batch goes through WhisperKit's CoreML inference. File mode uses `AVAudioFile` for duration. History, capped at 50, persists to `Documents/echo-history.json`.

## Build

```bash
xcodegen generate
open voxprint.xcodeproj
```

Pick `Voxprint-iOS` or `Voxprint-macOS`. The Whisper model downloads once on first launch (about 39 MB tiny, 150 MB base, 500 MB small) into Application Support. After that it loads instantly. Auto mode picks the size for your device.

## This Week / This Month

**This week**
- [ ] Build + upload new Mac build (icon source fixed 2026-06-30)
- [ ] Fix macOS TestFlight upload "Invalid Bundle OS Type code" error
- [ ] Fix macOS NavigationSplitView background seam bug

**This month**
- [ ] XCTest suite + snapshot tests
- [ ] Apple Shortcut integration

## Roadmap

XCTest suite, snapshot tests, Apple Shortcut integration.

- [ ] Fix macOS NavigationSplitView background seam — sidebar vibrancy material renders a visibly different shade than the detail pane despite both using `Color(.windowBackgroundColor)`. Needs a real styling pass (e.g. `.navigationSplitViewStyle` override or custom sidebar background), not a one-line value fix.
- [ ] Mac TestFlight: `fastlane mac_beta` lane added 2026-06-21. Fixed missing `CFBundlePackageType` in `Sources/macOS/Info.plist` (confirmed `APPL` in the built archive), but `pilot` upload still fails with the same "Invalid Bundle OS Type code" error from `altool` — points to the export/.pkg step, not the source Info.plist. Needs further debugging before this can ship to TestFlight.

## License

MIT 2026, Joshua Trommel

## Whitepaper

[Technical whitepaper](WHITEPAPER.md)
