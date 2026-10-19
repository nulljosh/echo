# Notate (was Voxprint, was Echo), CLAUDE.md

On-device Whisper transcription. iOS 17 + macOS 14, one unified ASC record (6782604262, Universal Purchase). WhisperKit via SPM. `roadmap.md` is the queue. `MONEY.md` is the price. `asc versions list --app 6782604262` is the truth on versions, never write them here.

## Frozen forever

Renamed Echo → Voxprint 2026-07-29, Voxprint → Notate 2026-09-21. The Notate store listing name applies with 1.4.1, when the binary says Notate too (re-probe with `asc apps rename` on the pending app info first). Xcode targets, schemes and the Pages project keep the name Voxprint, renaming them buys nothing. These keep the old name on purpose. Renaming any of them orphans existing installs:
`com.nulljosh.echo*` bundle IDs, `echo.*` UserDefaults keys, the `echo-models` model folder, `echo-history.json`.

## Money

No Pro, no IAP, no paywall code. Removed in 1.4.0. The app goes $0.99 upfront, but only flip the price AFTER 1.4.0 is approved: while 1.3.9 (free + $1 Pro) is the live build, a paid download would charge people twice. The old IAP `com.nulljosh.echo.unlock` still exists in ASC, unused.

## Structure

```
Sources/
  iOS/ macOS/   VoxprintApp.swift, Info.plist, Assets.xcassets (WhatsNewSheet is iOS)
  Models/       TranscriptionEntry
  Services/     TranscriptionEngine, AudioCapture, SpeechManager
  Views/        ContentView, RecordButton, TranscriptionView, WaveformBarsView,
                HistoryView, SettingsView, SplashView
Tests/          unit tests + ModelRecoveryTests (the end-to-end gate)
UITests/        fastlane snapshot screenshots
watchos/        standalone voice memo recorder, own xcodegen project
docs/           landing (index.html + landing.css, Notate Sans, footer like joshuatree) + web demo (app.html)
fonts/          Notate Sans, derived from Inter under the OFL, build.py rebuilds it. Landing and brand only, the apps keep the system font
brand/          icon, tokens.css, BRAND.md
```

**TranscriptionEngine** owns everything: model load, 2s live batches (8s trailing window, greedy), file transcription, history (max 50). Auto picks the model from device RAM.

**Model loading, read before touching it.** WhisperKit downloads into a cache iOS can purge, so the engine copies the model to `Application Support/echo-models/<model>` (temp name, then move, so a kill mid-copy cannot leave half a model). `cachedFolder` checks that stable folder by name first, because the absolute path stored in UserDefaults dies on every app update. If a load throws, every local copy is wiped and it tries once more clean. 1.3.9 shipped without this and bricked phones.

Since 1.4.2 the app ships tiny, base and small inside `BundledModels/` (fetched by `scripts/fetch-tiny-model.sh`, gitignored, Release builds fail without it), so nothing downloads and first launch works offline. `loadModel` loads the chosen model straight from the bundle (`bundled(_:)`). Only a model that does not ship (large turbo, picked under Advanced) uses a cached copy, or runs tiny while `upgrade(to:)` downloads it. A broken model falls back to bundled tiny. The new kit waits in `pending` and swaps in through `applyPendingUpgrade()` when nothing is recording. `blockingLoad` only runs when no model is bundled. Custom words (`customWords`, UserDefaults `notate.customWords`) become Whisper `promptTokens`. `Cleanup.swift` wraps Apple Foundation Models and is only shown where the system model is available.

**SettingsView**: appearance, speak-back voice, language (own page, every Whisper language), custom words, status. The model picker is under Advanced on purpose. Users should not need it.

Accent color is the asset catalog blue. Buttons and splash use `Color.accentColor`, not `Color.primary`. Icon is a white sound wave turning into two lines of text on a #0074D9 gradient, built from `Notate.icon` (Icon Composer) by the brand skill. Always blue, never red. The Mac and iOS targets both use it (`ASSETCATALOG_COMPILER_APPICON_NAME: Notate`), there is no AppIcon.appiconset. Products are named Notate.app; only the Xcode target and module names still say Voxprint (`PRODUCT_MODULE_NAME: Voxprint_macOS`, the tests import it).

## Build, test, ship

```bash
xcodegen generate            # no checked-in truth but project.yml
xcodebuild build -scheme Voxprint-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
asc workflow run ship-ios VERSION:x.y.z     # then ship-mac
```

The QA tests plant a corrupt model (the engine must heal), break the chosen model (it must fall back to the bundled tiny one), check custom words never blank real `say` speech, transcribe real speech, and run on-device cleanup live when the Mac has Apple Intelligence. It is the first step of both ship workflows. Never remove it, never ship on "it builds".

Ship gotchas, all seen for real:
- The workflow's publish step fails on a new version: the build is still processing and the version record does not exist. Finish by hand: `asc versions create`, set whatsNew with `asc localizations update --id`, wait for the build to go VALID (`asc builds uploads list`), then `asc review submit --build-id`.
- App icon PNGs must have no alpha channel (error 90717). Flatten with `magick ... -background "#0074D9" -alpha remove -alpha off`.
- Versions live only in `project.yml`. Info.plists use `$(...)`.
- Do not edit Sources while an archive is running.

## Landing

`docs/` on Cloudflare Pages, project `voxprint`, domain notate.heyitsmejosh.com (voxprint.heyitsmejosh.com still points here). A push deploys nothing:

```bash
npx wrangler pages deploy docs/ --project-name=voxprint --branch=main
```

## Notes

- `NSLock` guards `audioBuffer` (tap thread vs @MainActor)
- macOS drag-drop copies to temp (security scope). macOS has `app-sandbox`
- `PrivacyInfo.xcprivacy` in both targets, `ITSAppUsesNonExemptEncryption=false`
- DEVELOPMENT_TEAM: QMM486NPYC
- Icons: generate from `icon.svg`, never qlmanage

## The loop

App Store fix loop lives at docs/LOOP-HANDOFF.md. Phase 2 fleet audit starts after 22:00 usage reset.
