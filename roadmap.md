# Echo roadmap

History lives in git log. This file only holds what is still open.

## Road to v2.0 (2026-10-19)

v2.0 ships when every item below is done, QA'd and live. One item per loop tick.

- [ ] 9. Store name to Echo (renamed 2026-10-20). The moment Mac 2.0 clears review and an app info is editable: `asc apps info list --app 6782604262`, then `asc apps rename --app 6782604262 --app-info <editable id> --locale en-US --name Echo` (fallback Calliope), read back 3 times, then ship the next build so the binary says Echo too.
- [ ] 8. Ship 2.0 on iPhone, Watch and Mac (iPhone + Watch live 2026-10-19, landing deployed; Mac waiting for review)

## Blocked on Joshua

- [ ] One real call in meeting mode on the Mac (the screen-audio permission prompt needs a person).

## After 2.0

- [ ] Keyboard: dictate into any app. The big one, and the gap Willow ($19/month, cloud) and Otter leave open. Keyboard extensions get very little memory, so the keyboard hands off to the main app to transcribe. Own project.
- [ ] Native (kmp) port. Sibling apps have one, this doesn't.
- Skip: accounts, sync, SOC 2. We have no server. That is the pitch.

## Ingested 2026-10-19
Source: Apple Note, screenshots in `notes/attachments/2026-10-19/echo-1..5.png`.
- [ ] "What's new" sheet overflows the screen (echo-4.png, the bottom sheet is cut off).
- [ ] Settings and the other top-right icons should be a nav bar at the bottom, not small icons in the top right (echo-2.png).
- [ ] Settings: Speak-Back Voice is way too long. Make it a collapsible list or similar (echo-1.png, echo-3.png). Duplicate names (Eddy, Flo, Sandy, Shelley) show twice.
- [ ] Add ElevenLabs integration for better playback.
- [ ] Simplify the model list and make it more readable (echo-5.png: Auto, Tiny, Base, Small_216Mb, Large, Apple).
- [ ] Remove the Status row from Settings (echo-3.png). His words: get rid of it.
