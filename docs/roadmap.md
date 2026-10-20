# Echo roadmap

History lives in git log. This file only holds what is still open.

## Road to v2.0 (2026-10-19)

v2.0 ships when every item below is done, QA'd and live. One item per loop tick.

- [ ] 9. Store name to Echo (renamed 2026-10-20). The moment Mac 2.0 clears review and an app info is editable: `asc apps info list --app 6782604262`, then `asc apps rename --app 6782604262 --app-info <editable id> --locale en-US --name Echo` (fallback Calliope), read back 3 times, then ship the next build so the binary says Echo too.
- [ ] 8. Ship 2.0 on iPhone, Watch and Mac (iPhone + Watch live 2026-10-19, landing deployed; Mac waiting for review)

## Blocked on Joshua

- [ ] One real call in meeting mode on the Mac (the screen-audio permission prompt needs a person).

## Next (decided 2026-10-20)

- [ ] Apple first, Whisper fallback. SpeechTranscriber (iOS 26, macOS 26) becomes the default for live speech and files wherever Apple has the language; WhisperKit stays for older systems and the rest of the 99 languages. Then stop bundling base and small to cut the app by most of its size.
- [ ] Optional account. Sign in with Apple or email through jaybulb-api, profile, history sync, forgot password through authmail, delete account in Settings. The app keeps working fully without one; the pitch stays "no account needed". Refresh privacy.html and the App Store privacy answers in the same change.

## After 2.0

- [ ] Keyboard: dictate into any app. The big one, and the gap Willow ($19/month, cloud) and Otter leave open. Keyboard extensions get very little memory, so the keyboard hands off to the main app to transcribe. Own project.
- [ ] Native (kmp) port. Sibling apps have one, this doesn't.
- Skip: required accounts, SOC 2. Transcription never touches a server. That is the pitch.

## Ingested 2026-10-19
Source: Apple Note, screenshots in `notes/attachments/2026-10-19/echo-1..5.png`.
- [ ] "What's new" sheet overflows the screen (echo-4.png, the bottom sheet is cut off).
- [ ] Speak-Back Voice: duplicate names (Eddy, Flo, Sandy, Shelley) show twice in the picker. Show quality or drop the lower one.
- [ ] Add ElevenLabs integration for better playback.
- [ ] Simplify the model list and make it more readable (echo-5.png: Auto, Tiny, Base, Small_216Mb, Large, Apple).
