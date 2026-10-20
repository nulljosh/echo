# Echo roadmap

History lives in git log. This file only holds what is still open. Repo versions follow shipped batches; the App Store follows when Joshua says ship.

## v2.3: Joshua's notes and hardening

- [ ] Benchmarks with a real human voice clip (noise, accent) so the word error column separates the engines.
- [ ] Split TranscriptionEngine into extension files by area (model loading, live, files, Apple, history), no logic changes.

## v2.4: Apple first, part 2

- [ ] Custom words through SpeechAnalyzer's contextual strings, so they no longer force Whisper.
- [ ] Meeting mode on Apple: two sessions, mic and call, labelled You and Them.
- [ ] Stop bundling base and small once Apple covers the common languages, to shrink the app.

## v3.0: dictate into any app

- [ ] Keyboard extension on iPhone. Keyboards get very little memory, so it hands the audio to the app to transcribe. The gap Willow ($19 a month, cloud) and Otter leave open.

## Store and account (needs Joshua or Apple)

- [ ] Store name to Echo the moment Mac 2.0 clears review and an app info is editable: `asc apps info list --app 6782604262`, then `asc apps rename --app 6782604262 --app-info <editable id> --locale en-US --name Echo` (fallback Calliope), read back 3 times, then ship a build that says Echo.
- [ ] Ship 2.0 on Mac (waiting for review). iPhone and Watch 2.0 are live.
- [ ] Before the next submission: update the ASC privacy answers and PrivacyInfo.xcprivacy per docs/APPSTORE.md, and run one real sign up, confirm, sign in, rename and delete with an inbox Joshua owns.
- [ ] Sign in with Apple: enable the capability on com.nulljosh.echo, regenerate the iOS and Watch profiles, add the bundle IDs to APPLE_AUDIENCES on jaybulb-api (the id_token grant already exists). Needs Joshua's yes.
- [ ] One real call in meeting mode on the Mac (the screen audio permission prompt needs a person).
- [ ] ElevenLabs playback (Joshua's note). It would send transcript text to a cloud service, so it breaks "nothing leaves the device" unless it is opt-in. His call.

## Later

- [ ] Native (KMP) port. Sibling apps have one, this one does not.
- Skip: required accounts, SOC 2. Transcription never touches a server. That is the pitch.
