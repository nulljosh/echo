# Directory listings

Name: Echo
One-liner: Speech to text that never leaves your device.
Description: Echo runs WhisperKit locally on iPhone and Mac, so audio is transcribed on-device with no cloud call, no account, and nothing uploaded. It transcribes live from the mic in real time or from a dropped-in file, auto-detecting across every language Whisper supports.
Category: Productivity / Privacy / Developer Tools
Links: https://echo.jaybulb.com · https://apps.apple.com/app/id6782604262 · https://github.com/nulljosh/echo

## AlternativeTo
List as an alternative to cloud dictation apps (Otter.ai, Aiko). Lead with "on-device, no cloud" as the differentiator. Use the one-liner and description above.

## Indie Hackers (Products)
Use the one-liner and description above. Indie Hackers rewards a real founder story in the comments, reuse the maker story from `launch/producthunt.md`'s first comment, don't paste it verbatim, keep it in first person as a product update instead of a launch announcement.

## BetaList
Skip. Echo is already public on the App Store and Product Hunt, BetaList is pre-launch only.

## Uneed
Use the one-liner and description above. Tag: Productivity, AI, Privacy.

## SaaSHub
List under Productivity > Transcription. Note the pricing model in the listing field exactly: one payment of $0.99, everything included, no subscription.

## dev.to
Build-story angle, since the technical hook is real (on-device Whisper, not a wrapper around an API).

Title: How Echo keeps Whisper transcription fully on-device on iPhone and Mac

Draft outline:
- The problem: cloud dictation apps mean every recording passes through someone else's server before it becomes text.
- The core mechanic: `TranscriptionEngine` batches live audio in 2-second windows and only re-decodes the trailing ~8s each tick, so decode time stays flat as a recording grows instead of climbing with it.
- Model handling: WhisperKit's default cache directory is purgeable by iOS under storage pressure, so after the first download Echo copies the model into Application Support, which iOS won't purge, so later launches load instantly.
- Model selection is automatic based on device RAM, no picker, because the right model is a device fact, not a preference.
- Close with pricing: everything included for $0.99 once, no subscriptions, and a link to the GitHub repo since the code is open.
