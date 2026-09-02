# Voxprint (was Echo), CLAUDE.md

App renamed Echo → Voxprint 2026-07-29 (App Store required a single-word rename; "Echo" alone was already taken). App Store name applied via new draft v1.3.6 on the single unified app record (6782604262, iOS+macOS Universal Purchase), pending review submission to go live. CFBundleName/CFBundleDisplayName in both Info.plists updated. Repo, folder, Xcode project and all four scheme names renamed to Voxprint 2026-08-28. The `com.nulljosh.echo*` bundle IDs, the `com.nulljosh.echo.unlock` IAP id, the `echo.*` UserDefaults keys and the `echo-models` cache stay frozen forever, renaming them orphans existing installs.

v1.3.2 (build 7). On-device Whisper transcription. iOS 17 + macOS 14. WhisperKit via SPM. Versions live only in `project.yml` (`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`); Info.plists reference `$(...)`, never hardcode them.

## App Store submission state (2026-06-23)
Recent commits focused on getting the macOS app icon to render correctly in App Store Connect (squircle-mask clipping, low-res compiling, missing 1024x1024 entry) and added a macOS `ExportOptions.plist` for ASC upload, macOS build bumped to 6. `PrivacyInfo.xcprivacy` bundled in both targets. `ITSAppUsesNonExemptEncryption=false` set. macOS has `app-sandbox` (required for Mac App Store IAP). Working tree currently has uncommitted changes to `voxprint.xcodeproj/project.pbxproj` plus untracked `.asc/`, `ExportOptions-iOS.plist`, and `fastlane/test_output/`.

## Open design question (2026-06-20)
A task note asked whether to switch the whole app to the clrs.cc color palette (and use it as the design system across all apps, not just Echo), that's a cross-repo design decision, not applied. Settings icon made more obvious (`gearshape.fill`, larger, `.primary`) and transcript view's scroll indicators/bounce tuned down per the same note; both verified via `xcodebuild build -scheme Voxprint-macOS` (BUILD SUCCEEDED).

## Recent Changes (v1.3.2)
- Fixed model re-download on every launch: WhisperKit downloads to HuggingFace Caches dir, which iOS can purge. After purge, UserDefaults path was stale → re-download. Fix copies model to Application Support after first download; subsequent launches load instantly from there.

## Recent Changes (v1.3.0)
- Fixed model-folder cache actually being used in `loadModel()` (was dead code, every launch re-resolved via HuggingFace)
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
  iOS/          VoxprintApp.swift, Info.plist, Assets.xcassets
  macOS/        VoxprintApp.swift, Info.plist, echo-mac.entitlements, Assets.xcassets
  Models/       TranscriptionEntry (Codable — id, text, date, duration, model)
  Services/     TranscriptionEngine, AudioCapture
  Views/        ContentView, RecordButton, TranscriptionView, WaveformBarsView,
                HistoryView, SettingsView, SplashView
```

## Key Components

**TranscriptionEngine**, Loads history, manages WhisperKit model, batches audio every 2s, handles file transcription. Auto-selects model based on device RAM.

**AudioCapture**, AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32. RMS per buffer drives waveform.

**ContentView**, Record/file input, bottom bars (iOS: copy | share | record/file | history; macOS: copy | share | record/file). Cmd+R shortcut on macOS.

**SettingsView**, Model picker (Auto/Tiny/Base/Small), language picker (auto-detect + 11), status indicator.

**WaveformBarsView**, 5 animated bars responding to audio level.

## Build

```bash
xcodegen generate
open voxprint.xcodeproj
```

## Web Deployment

Echo's landing page (`web/index.html`, styles inline) is hosted on **Cloudflare Pages**, not Vercel. The site has no git auto-deploy configured, changes require manual deployment after pushing commits:

```bash
npx wrangler login
npx wrangler pages deploy web/ --project-name=echo --branch=main
```

Domain: `voxprint.heyitsmejosh.com` (Cloudflare DNS CNAME pointing to Cloudflare Pages). Project name in Pages dashboard: `echo` (unchanged; the `echo.` host still resolves as an alias).

## Targets

- `Voxprint-iOS`: `com.nulljosh.echo`, iOS 17+
- `Voxprint-macOS`: `com.nulljosh.echo` (shares the iOS id for Universal Purchase), macOS 14+
  - Entitlements: `audio-input`, `network.client`, `files.user-selected.read-only`

## Notes

- Icons: Swift/NSImage generated (don't use qlmanage)
- `NSLock` guards `audioBuffer` (tap thread ↔ @MainActor)
- macOS drag-drop copies to temp (security scope)
- History: max 50, atomic JSON persistence
- DEVELOPMENT_TEAM: QMM486NPYC

## Imported from echo.pdf (2026-06-21)
- [x] Mac screenshots, fixed and verified during this pass (Screen Recording permission granted, `fastlane mac_screenshots` now captures the real app window).
- [ ] Push IPA/upload to TestFlight via `fastlane beta`/`mac_beta`, go-ahead given, not yet run.
- [ ] Watch companion app, net-new watchOS target, not started.

## In progress (2026-07-14), resume here
Plan file: `~/.claude/plans/federated-discovering-hamster.md`. Three-part ask: language ID feature, ship iOS, new landing page. Session hit usage limit mid-flight, only step 1 landed.
- [x] Language detection: `TranscriptionEngine` now reads `DecodingResult.language`/`languageProbs` off the existing auto-mode transcribe call (no extra WhisperKit call), sets `detectedLanguage`/`isUnusualLanguage` when the code isn't in the picker's 11 languages. Committed `6b0cf45`, pushed. Build verified via `xcodebuild build -scheme Voxprint-macOS`.
- [x] Wire `detectedLanguage`/`isUnusualLanguage` into `TranscriptionView.swift` as a visible badge, DONE (verified 2026-08-03): `ContentView.swift:179` passes `unusualLanguage`, `TranscriptionView.swift:117-118` renders "Unusual language detected: …" with a 0.2s ease-out animation. Item was stale.
- [x] Ship iOS, SUPERSEDED: 1.3.5 shipped and is READY_FOR_SALE; 1.3.6 (Voxprint rename) built + submitted 2026-08-03. Note `asc submission-health` is not a real subcommand (it's a skill name), use `asc versions list` / `asc review submissions-*`.
- [x] Landing page, DONE: `web/` exists and `voxprint.heyitsmejosh.com` returns 200 (verified 2026-08-03). Style after `~/Documents/Code/lexly/index.html` + `css/lingo.css` (DM Sans/Geist body + Fraunces-style serif headings, no monospace, 2-col hero with plain `<img>` screenshots + soft shadow/glow, light+dark via `prefers-color-scheme`). Pull screenshots from `fastlane/screenshots/en-US/`. Deploy target + Cloudflare CNAME still TBD.

## Icon redesign (2026-07-26 night)
- [x] Icon reworked from teal-squircle "snowman circles + waveform" to a single clean mic glyph on clrs.cc blue (#0074D9). All of `icon.svg`/`icon-mac.svg`/`web/assets/icon.svg` plus iOS/macOS Assets.xcassets PNGs regenerated and synced; macOS build verified (`xcodebuild build -scheme Voxprint-macOS`).
- [ ] Not yet shipped: v1.3.4 is already in App Store review with the old teal icon, this new icon needs a version bump (1.3.5) and a fresh `asc workflow run ship-ios` once the current review clears, don't resubmit mid-review.

## From App Store.pdf (imported 2026-07-28)
- [ ] Echo Transcribe Mac (ASC 6783015101) duplicate record still needs merge/delete, support case 102949488998 filed 2026-07-22, dashboard-only. Joshua confirmed 2026-07-29 he'd delete it himself from the ASC app-info screen he was already on.

## Ship v1.3.5 (2026-07-29, SUBMITTED)
- [x] `project.yml` MARKETING_VERSION bumped 1.3.3 → 1.3.5, `xcodegen generate` run.
- [x] First `asc workflow run ship-ios VERSION:1.3.5` attempt failed at export: `Invalid large app icon... can't be transparent or contain an alpha channel` (code 90717), the new mic-glyph icon from the 2026-07-26 redesign had alpha.
- [x] Fixed: `magick Sources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png -background "#0074D9" -alpha remove -alpha off <same path>` to flatten. Committed `e9aed79`.
- [x] Re-ran `asc workflow run ship-ios VERSION:1.3.5` fresh with clean archive. Export mode `destination: upload` succeeded on ASC (build 202607290026, state: VALID). Workflow's built-in publish step failed (no local .ipa from upload mode), but ASC upload was successful. Ran `asc review submit` manually to complete submission. State: **WAITING_FOR_REVIEW, submitted 2026-07-29T10:26:29Z**.
