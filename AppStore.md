# Echo — App Store Connect submission package

Everything below is paste-ready. Account-side steps are the only thing blocking submission; all copy, the privacy URL, and the build are done.

## Status (2026-05-30)
- iOS Release: **BUILD SUCCEEDED** (signing aside, verified this session).
- Device family set to iPhone-only (`TARGETED_DEVICE_FAMILY: "1"`) — iPhone screenshots only, no iPad QA.
- Privacy policy live target: **https://heyitsmejosh.com/echo/privacy.html** (file committed in nulljosh.github.io/echo/privacy.html — deploy the portfolio to make it live).
- Privacy manifest bundled, `ITSAppUsesNonExemptEncryption=false` set, StoreKit 2 local entitlement done.

## The one blocker (only Joshua can do these)
1. Enroll Apple Developer Program — $99 USD/yr. This gates every step below and every App Store dollar across all 38 apps. Highest-ROI $99 on the board.
2. Create app record: bundle `com.nulljosh.echo` (iOS), team QMM486NPYC.
3. Create IAP: non-consumable `com.nulljosh.echo.pro`, $7.99 (Tier 8), reference name "Echo Pro". Attach one paywall screenshot (IAP is reviewed with the first version).
4. App Privacy: select **Data Not Collected** (paste the privacy URL above).
5. Run the macOS sandbox smoke test before submitting the Mac build (mic permission, WhisperKit model lands in sandbox container, file import works). Ship iOS first if the Mac sandbox test slips — do not let it block the iPhone submission.

---

## Listing metadata (copy-paste)

**App Name** (30 char max)
`Echo: On-Device Transcription`

**Subtitle** (30 char max)
`Voice to text, nothing leaves`

**Category**: Primary Productivity, Secondary Utilities

**Promotional Text** (170 char, editable without resubmit)
`Transcribe voice and audio files entirely on your iPhone. No account, no cloud, no subscription. Buy it once and own it.`

**Keywords** (100 char max, comma-separated, no spaces)
`transcribe,voice to text,whisper,dictation,audio to text,speech,recorder,offline,private,notes,memo`

**Description**
```
Echo turns speech into text right on your iPhone. No account, no cloud, no subscription. Your audio never leaves the device.

Powered by an on-device Whisper model, Echo transcribes live from the microphone or from audio files you import. Everything runs locally, so it works on a plane, in a basement, anywhere, and nothing you say is ever uploaded.

FREE, FOREVER
- Unlimited live microphone transcription
- Auto, Tiny, and Base models
- Full history, copy, and share
- 12 languages with auto-detect

ECHO PRO, ONE PAYMENT
- Unlimited audio file transcription
- The Small model, the most accurate
- One purchase. Not a subscription, ever.

WHY ECHO
- On device. Your voice stays yours.
- No account, no sign-up, no tracking.
- No monthly fee. Own it once.

Echo is built for people who want their words transcribed without handing them to a server.
```

**What's New** (first version)
```
First release. On-device transcription for iPhone. Live mic and file import, 12 languages, full history, all running locally. Echo Pro unlocks unlimited file transcription and the most accurate model for one payment.
```

**Support URL**: `https://heyitsmejosh.com`
**Marketing URL** (optional): `https://heyitsmejosh.com/echo/`
**Privacy Policy URL**: `https://heyitsmejosh.com/echo/privacy.html`

---

## App Review notes (paste into Review Information)
```
Echo transcribes speech entirely on-device using a Whisper model (WhisperKit). No account or login is required and no data leaves the device, so there are no demo credentials needed.

To test the in-app purchase:
1. Live microphone transcription is free and unlimited. Tap record and speak.
2. File transcription is free for the first 3 files, then prompts Echo Pro ($7.99, one-time non-consumable, com.nulljosh.echo.pro).
3. "Restore Purchase" is in the paywall and in Settings.

The first model download requires network once; after that the app is fully offline. Microphone permission is requested only when the user taps record.
```

## Screenshots needed (iPhone 6.7" / 6.9", use the `screenshot` skill)
1. Live transcription with the waveform animating
2. A finished transcript with the share/copy bar
3. History list
4. The Echo Pro paywall (doubles as the IAP review screenshot)
5. Settings showing model + language pickers

## Privacy nutrition label answers
- Data used to track you: **None**
- Data linked to you: **None**
- Data not linked to you: **None**
- Result: **Data Not Collected** (matches PrivacyInfo.xcprivacy and privacy.html)
