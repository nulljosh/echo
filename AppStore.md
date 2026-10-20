# Echo - App Store Connect submission package

v1.4.0 is in review on iOS and Mac as of 2026-09-21. Price flips to $0.99 upfront after approval. No more Pro tier or in-app purchases.

## Status (2026-09-21)
- iOS and Mac: v1.4.0 **in review**.
- Everything is now included for the one-time $0.99 purchase. No IAP, no paywall.
- All languages Whisper knows (about 99) are now in the picker, with auto-detect.
- Model is auto-picked by device; manual override in Settings > Advanced.
- Privacy policy live target: **https://notate.heyitsmejosh.com/privacy.html**.
- Privacy manifest bundled, `ITSAppUsesNonExemptEncryption=false` set.

---

## Listing metadata (copy-paste)

**App Name** (30 char max)
`Echo: On-Device Transcribe`

**Subtitle** (30 char max)
`Voice to text, nothing leaves`

**Category**: Primary Productivity, Secondary Utilities

**Promotional Text** (170 char, editable without resubmit)
`Transcribe voice and audio files entirely on your iPhone. No account, no cloud, no subscription. One payment, own it forever.`

**Keywords** (100 char max, comma-separated, no spaces)
`transcribe,voice to text,whisper,dictation,audio to text,speech,recorder,offline,private,notes,memo`

**Description**
```
Echo transcribes speech, music, and audio files entirely on your iPhone. No account, no cloud, no subscription. Your audio never leaves the device.

Powered by an on-device Whisper model, Echo transcribes live from the microphone or from audio files you import. Whether it's your voice, song lyrics, podcasts, or lectures, everything runs locally, so it works on a plane, in a basement, anywhere, and nothing you say is ever uploaded.

ONE PAYMENT, EVERYTHING INCLUDED
- Unlimited live microphone transcription
- Unlimited audio file transcription
- Every language Whisper knows with auto-detect
- All models (Auto, Tiny, Base, Small, Turbo)
- Full history, copy, and share
- Speak back with system voice

WHY ECHO
- On device. Your voice stays yours.
- No account, no sign-up, no tracking.
- No subscription, no recurring charge.

Echo is built for people who want their words, music, and audio transcribed without uploading to a server.
```

**What's New** (version 1.4.0)
```
Fixed a model error that could stop the app from loading. Everything is unlocked for everyone, no in-app purchases. Every language Whisper knows is now in the picker. Cleaner settings.
```

**Support URL**: `https://heyitsmejosh.com`
**Marketing URL** (optional): `https://notate.heyitsmejosh.com/`
**Privacy Policy URL**: `https://notate.heyitsmejosh.com/privacy.html`

---

## App Review notes (paste into Review Information)
```
Echo transcribes speech entirely on-device using a Whisper model (WhisperKit). No account or login is required and no data leaves the device, so there are no demo credentials needed.

All features are included with the app purchase. No in-app purchases, no paywalls, no paywall screenshots. Everything is unlocked.

Test transcription:
1. Live microphone transcription: tap record and speak, text appears as you talk.
2. File import: drag or select an audio file, it transcribes the whole thing.
3. Any of the 99+ languages Whisper supports, with auto-detect.
4. Settings > Advanced lets you manually pick a model, but Auto is recommended.

The first model download requires network once; after that the app is fully offline. Microphone permission is requested only when the user taps record.
```

## Screenshots needed (iPhone 6.7" / 6.9", use the `screenshot` skill)
1. Live transcription with the waveform animating
2. A finished transcript with the share/copy bar
3. History list
4. Settings showing model + language pickers
5. Optional: file import in progress

## Privacy nutrition label answers
- Data used to track you: **None**
- Data linked to you: **None**
- Data not linked to you: **None**
- Result: **Data Not Collected** (matches PrivacyInfo.xcprivacy and privacy.html)

---

## v1.4.0 shipping changes (2026-09-21)
- All transcription features now included in the base $0.99 purchase.
- Removed Echo Pro in-app purchase (`com.nulljosh.echo.unlock`).
- Removed paywall UI entirely.
- Expanded language picker to all 99+ languages Whisper supports.
- Model selection moved to Settings > Advanced (Auto still default).
- Simplified settings screen.
- Fixed model loading bug that could prevent app launch.
