# Echo (was Notate, was Voxprint, was Echo), CLAUDE.md

On-device Whisper transcription. iOS 17 + macOS 14, one unified ASC record (6782604262, Universal Purchase). WhisperKit via SPM. `docs/roadmap.md` is the queue. `docs/MONEY.md` is the price. Every other markdown file lives in `docs/`. `asc versions list --app 6782604262` is the truth on versions, never write them here.

## Frozen forever

Renamed Echo → Voxprint 2026-07-29, Voxprint → Notate 2026-09-21, Notate → Echo 2026-10-20 (back to the first name). The repo, site, display name and in-app strings say Echo. The App Store listing still says Notate until Apple accepts "Echo" on the next editable app info: both app infos were locked on 2026-10-20 (one live, Mac 2.0 in review). Probe Echo first, then Calliope, with `asc apps rename --app-info <editable id>`. The store and site names differ on purpose until then; Joshua chose this knowing the risk, so do not "fix" it back. Xcode targets, schemes and the Pages project keep the name Voxprint, renaming them buys nothing. These keep old names on purpose. Renaming any of them orphans existing installs or saved settings:
`com.nulljosh.echo*` bundle IDs, `echo.*` UserDefaults keys, the `echo-models` model folder, `echo-history.json`, and the Notate-era keys `notate.customWords`, `notate.meetingMode`, `notate.startRecording`. The signing profiles are still named "Notate iOS App Store" and "Notate Watch App Store" on Apple's side. notate.jaybulb.com keeps serving the site.

## Money

No Pro, no IAP, no paywall code. Removed in 1.4.0. The app goes $0.99 upfront, but only flip the price AFTER 1.4.0 is approved: while 1.3.9 (free + $1 Pro) is the live build, a paid download would charge people twice. The old IAP `com.nulljosh.echo.unlock` still exists in ASC, unused.

## Structure

```
Sources/
  iOS/ macOS/   VoxprintApp.swift, Info.plist, Assets.xcassets (WhatsNewSheet is iOS)
  Models/       TranscriptionEntry
  Services/     TranscriptionEngine (+Models, +Live, +Apple, +Files), AppleSpeech, AudioCapture, Account, SpeechManager
  Views/        ContentView, RecordButton, TranscriptionView, WaveformBarsView,
                HistoryView, SettingsView
Tests/          unit tests + ModelRecoveryTests (the end-to-end gate)
UITests/        fastlane snapshot screenshots
Keyboard/       the Echo keyboard extension (v3.0), see DictationBridge
watchos/        standalone voice memo recorder, own xcodegen project
docs/           landing (index.html + landing.css + tokens.css, Hermes-style, 1-bit ordered-dither art in docs/art) + web demo (app.html)
brand/          icon, tokens.css, BRAND.md
```

**TranscriptionEngine** owns everything, split by area into `TranscriptionEngine+Models/+Live/+Apple/+Files.swift` (stored state stays in the main file, so members are internal, not private): model load, 2s live batches (greedy, decodes only audio after the last committed segment and commits finished segments past 15 s, so the live text keeps everything said), file transcription, history (no cap). The word being heard is highlighted in the accent. Auto picks the model from device RAM.

**Apple first** (2026-10-20): on iOS 26 and macOS 26, Auto records through `AppleSpeech.Live` (SpeechAnalyzer) when Apple's model for the language is installed; `loadModel` asks the system to install it. The engine still fills `audioBuffer`; `pumpApple` drains it into Apple every 200 ms and `finishApple` takes the final text and timed lines. Mac meetings run on Apple too: it hears the mixed mic and call audio and `labelled` marks each line You or Them from the loudness frames, as Whisper does (`testAppleMeetingSpeakerLabels`). Whisper runs instead with custom words, on older systems, for other languages, or if the Apple session fails to start. Whisper still loads in the background so the fallback is instant. `testAppleLiveTranscribesRealSpeech` is the gate.

**Model loading, read before touching it.** WhisperKit downloads into a cache iOS can purge, so the engine copies the model to `Application Support/echo-models/<model>` (temp name, then move, so a kill mid-copy cannot leave half a model). `cachedFolder` checks that stable folder by name first, because the absolute path stored in UserDefaults dies on every app update. If a load throws, every local copy is wiped and it tries once more clean. 1.3.9 shipped without this and bricked phones.

Since 1.4.2 the app ships tiny and small inside (base stopped shipping in 2.5: small is more accurate, and it saved 143 MB) `BundledModels/` (fetched by `scripts/fetch-tiny-model.sh`, gitignored, Release builds fail without it), with their tokenizers (without tokenizer.json WhisperKit fetches it from the internet), so nothing downloads and first launch works offline. Tiny loads first on the GPU (ready in seconds, the Neural Engine compiles small for minutes on first launch), small swaps in from the bundle in the background. Record works before any model is ready; audio buffers and catches up. `loadModel` loads the chosen model straight from the bundle (`bundled(_:)`). Auto only ever picks a model that ships. Only one that does not (base or large turbo, picked under Model in Settings) uses a cached copy, or runs tiny while `upgrade(to:)` downloads it. A broken model falls back to bundled tiny. The new kit waits in `pending` and swaps in through `applyPendingUpgrade()` when nothing is recording. `blockingLoad` only runs when no model is bundled. Custom words (`customWords`, UserDefaults `notate.customWords`) become Whisper `promptTokens`. `Cleanup.swift` wraps Apple Foundation Models and is only shown where the system model is available.

**Keyboard** (v3.0): iOS keeps keyboards off the microphone, so `Keyboard/` never records. Its dictate key opens `com.nulljosh.echo://dictate`; ContentView starts recording with a `.playAndRecord` session and the `audio` background mode keeps it going while the person goes back. The keyboard posts stop through `DictationBridge` (App Group `group.com.nulljosh.echo` defaults plus Darwin notifications), `stopRecording` publishes the text, and the keyboard types it at the cursor. Space, delete, return and globe keep it a real keyboard without Full Access (guideline 4.4.1). Never link WhisperKit into the extension.

**SettingsView**: one Form. Appearance, speak-back voice, language (own page on iOS, every Whisper language), custom words, model and its status. The model list sits one level down on purpose. Users should not need it.

**Account** (optional, 2026-10-20): `Services/Account.swift` talks to jaybulb-api (api.jaybulb.com) for sign up, sign in, forgot password, rename and delete; the refresh token is in the Keychain. Confirm and reset emails come from authmail with the Echo theme and land on `docs/account.html`. Transcripts never go to the server. Never make the account required: "works fully without one" is the pitch.

**ContentView**: the record button is part of the page, centred just above a native bottom bar (Joshua's call). iPhone: a `.bottomBar` toolbar with History, Share, More and Settings; the nav bar is only the title. Mac: `nativeBottomBar` (Apple's `safeAreaBar` on macOS 26) with Settings and the meeting toggle left, Share and More right; History is the sidebar, collapsed by default. No splash, no cards around the transcript, no mode switch: files come in through More, drag and drop on the Mac, or Open With.

Accent color is the asset catalog blue. The record button is tinted with `Color.accentColor`; icon buttons follow the system (primary in bars and glass). Type is the system font: every view uses `Font.echo(size, weight)`, which is SF Pro (Notate Sans was dropped 2026-10-20). Icon is a white voice wave that rings out, fades like an echo and settles into a written line, over a shorter line, on a #0074D9 gradient, built from `Echo.icon` (Icon Composer) by the brand skill. Always blue, never red. The Mac and iOS targets both use it (`ASSETCATALOG_COMPILER_APPICON_NAME: Echo`), there is no AppIcon.appiconset. Products are named Echo.app; only the Xcode target and module names still say Voxprint (`PRODUCT_MODULE_NAME: Voxprint_macOS`, the tests import it).

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
- Versions live only in `project.yml`. `asc xcode version edit` bumps the generated xcodeproj, so never run `xcodegen generate` between the bump and the archive or the build number resets to project.yml's.
- The Watch app needs manual export: `signing/` holds the "Notate iOS App Store" and "Notate Watch App Store" profiles (gitignored); export with an ExportOptions plist naming both, then `asc builds upload --ipa`. A build with a Watch app needs an APP_WATCH_ULTRA screenshot or review refuses it. Info.plists use `$(...)`.
- Do not edit Sources while an archive is running.

## Promo

`launch/echo-promo.mp4` (15 s vertical) is cut from real footage: the `-ECHO_DEMO 1` launch flag plays `Documents/demo.wav` through the live engine in real time, so the screen shows Echo genuinely transcribing the voiceover (Joshua's ElevenLabs v3 clone). Record the Mac app for live scenes (Apple's engine; the simulator only has Whisper and lags). Demo runs never save to history. The music bed is original, synthesized in numpy (the ElevenLabs keys have no music permission). On macOS put `-ApplePersistenceIgnoreState YES` before `-ECHO_DEMO 1`, or the bare YES opens as a document and no window shows.

## Landing

`docs/` on Cloudflare Pages, project `voxprint`, domain echo.jaybulb.com. A push deploys nothing:

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

docs/LOOP-HANDOFF.md holds Joshua's brief, the rules every tick follows, where things stand and the restart prompt. Read it before restarting the loop. docs/roadmap.md is versioned (v2.3, v2.4, v3.0) and its items have no leading numbers, so the issue sync gets real titles.
