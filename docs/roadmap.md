# Echo roadmap

History lives in git log. This file only holds what is still open. Repo versions follow shipped batches; the App Store follows when Joshua says ship.

## v2.5: Apple first, part 2

- Custom words stay on Whisper. Tested 2026-10-20 with made-up names: SpeechTranscriber ignores contextual strings (heard "J. Balvin" for Jaybulb with or without them), DictationTranscriber got one of two. Whisper's prompt gets both. Retest each new OS.
- Custom words also correct the transcript afterwards (`Glossary.swift`): a heard word one edit from a custom word, or two words run together, becomes the word. It is edit distance on single words, so a name that sounds right but spells far off ("J. Balvin" for Jaybulb) still slips through. Phonetic matching would fix that and could let Apple's engine handle custom words too.
- Base stopped shipping (2.5, 143 MB saved). Small stays: Whisper still runs on iOS and macOS before 26, with custom words and for languages Apple lacks.

## v3.0: dictate into any app

- The Echo keyboard is built (`Keyboard/`, `DictationBridge`). Keyboards cannot use the mic, so the dictate key opens Echo, which records in the background (audio background mode) while you go back; stop comes from the keyboard and the text is typed at the cursor. Opening Echo from a keyboard walks the responder chain, the route every dictation keyboard takes, with some review risk.
- [ ] Walk it on a real iPhone: add the keyboard, allow Full Access, dictate into Messages, stop from the keyboard. A simulator UI test could not get through iOS 27 Settings to add the keyboard (2026-10-20), so the device walk is the check.
- [ ] Next: keep the session warm for a few minutes after a dictation so the next one starts without opening Echo.

## Store and account (needs Joshua or Apple)

- [ ] App Store video header (new in iOS 27, autoplays at the top of the product page). Cut launch/echo-promo.mp4 to Apple's spec and attach it to the next iOS version (a live version cannot take new media). Check the crop on a real device, the ASC preview is reportedly off.

- [ ] Store name to Echo once 3.0.0 clears review and an app info is editable (both are locked now: one live, one waiting for review): `asc apps info list --app 6782604262`, then `asc apps rename --app 6782604262 --app-info <editable id> --locale en-US --name Echo` (fallback Calliope), read back 3 times, then ship a build that says Echo.
- [ ] 3.0.0 on iPhone, Watch and Mac, waiting for review (submitted 2026-10-26). Mac 2.0 and iPhone 2.0 are live. If Apple rejects, read the reason in Resolution Center and fix it.
- [ ] Before the next submission: update the ASC privacy answers and PrivacyInfo.xcprivacy per docs/APPSTORE.md, and run one real sign up, confirm, sign in, rename and delete with an inbox Joshua owns.
- [ ] Sign in with Apple: enable the capability on com.nulljosh.echo, regenerate the iOS and Watch profiles, add the bundle IDs to APPLE_AUDIENCES on jaybulb-api (the id_token grant already exists). Needs Joshua's yes.
- [ ] One real call in meeting mode on the Mac (the screen audio permission prompt needs a person).
- [ ] ElevenLabs playback (Joshua's note). It would send transcript text to a cloud service, so it breaks "nothing leaves the device" unless it is opt-in. His call.

## Later

- [ ] Native (KMP) port. Sibling apps have one, this one does not.
- Skip: required accounts, SOC 2. Transcription never touches a server. That is the pitch.
