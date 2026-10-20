# Echo roadmap

History lives in git log. This file only holds what is still open.

## Road to v2.0 (2026-10-19)

v2.0 ships when every item below is done, QA'd and live. One item per loop tick.

- [ ] 9. Store name to Echo (renamed 2026-10-20). The moment Mac 2.0 clears review and an app info is editable: `asc apps info list --app 6782604262`, then `asc apps rename --app 6782604262 --app-info <editable id> --locale en-US --name Echo` (fallback Calliope), read back 3 times, then ship the next build so the binary says Echo too.
- [ ] 8. Ship 2.0 on iPhone, Watch and Mac (iPhone + Watch live 2026-10-19, landing deployed; Mac waiting for review)

## Blocked on Joshua

- [ ] One real call in meeting mode on the Mac (the screen-audio permission prompt needs a person).

## Next (decided 2026-10-20)

- [ ] Apple first, part 2. Live Apple speech shipped in the repo 2026-10-20 (Auto uses it on iOS and macOS 26 when Apple's model is installed; Echo requests the install). Next: custom words through SpeechAnalyzer's contextual strings and meeting mode on Apple, so Whisper is only the fallback; then stop bundling base and small to shrink the app.
- [ ] Optional account, part 2. Email accounts shipped in the repo 2026-10-20 (sign up, confirm, sign in, forgot password, profile name, delete, privacy policy). Next: Sign in with Apple (enable the capability on com.nulljosh.echo, add the bundle IDs to APPLE_AUDIENCES on jaybulb-api, the id_token grant already exists), then history sync if wanted. Before the next submission: update the ASC privacy answers and PrivacyInfo.xcprivacy per docs/APPSTORE.md.

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
