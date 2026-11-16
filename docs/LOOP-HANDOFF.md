# Echo loop handoff (2026-11-15, evening)

## What the loop is
Joshua's brief, in his words: "to v4, 5-10 etc. Keep building roadmap. Keep updating benchmarks, improve efficiency and security and stability. Keep documentation 100%. Break up big god files." Subagents are allowed: one at a time, Haiku, in a worktree, on files the main loop is not touching.

Rules for every tick:
- One item from docs/roadmap.md per tick. QA gate green (`TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`) before every push. Mac and iOS both build.
- A batch of shipped items is a minor bump in `project.yml`, a tag and a GitHub release after CI is green. A major (v3.0) only for something keyboard-sized. Never filler versions.
- No App Store submission without Joshua's yes.
- Build only what the roadmap holds. New ideas go to Joshua as one line, not into code.
- Docs stay 100%: every source file and doc has a row in docs/ARCHITECTURE.md, numbers are measured, never remembered.
- Any UI change: rerun `bash scripts/update_screenshots.sh`, look at the shots, commit them.
- Stop rule: read the usage hook every tick. At about 88% weekly, run /checkpoint, stop the loop, send one line.

## Where things stand
- The loop is stopped. The last recorded state is 3.0.0 WAITING_FOR_REVIEW on iPhone and Mac (submitted 2026-10-26); it was not rechecked tonight, so run `asc versions list --app 6782604262` first.
- 3.1.0 is tagged (2026-11-15): Word (DOCX) export everywhere, and the Mac hot key moved to Control-Shift-Space because Control-Option-Space is macOS's input-source key. Closing the window and pressing the hot key reopens Echo already recording (commit 348e0fe).
- The keyboard has still not been walked on a real iPhone, so PR #51 stays held.
- Mac 2.0 and iPhone 2.0 are live. The store listing still says Notate until 3.0.0 clears review and the app info is editable.
- Landing work in docs/landing.css and docs/landing.js is uncommitted in the working tree; check it before the next push.
- Repo nulljosh/echo, folder ~/Documents/Code/echo, site https://echo.jaybulb.com (Pages project voxprint).

## Next, in order
1. Joshua walks the keyboard on a real iPhone: add it, allow Full Access, dictate into Messages, stop from the keyboard. Nothing below should build on the keyboard until this is done.
2. Press Control-Shift-Space for real in another app (Tink, speak, press again, Pop, paste). The test only sends the Carbon event.
3. Check 3.0.0 with `asc versions list --app 6782604262`. If rejected, read the reason and fix it. When it clears: store rename to Echo, read back 3 times.
4. Keep the session warm for a few minutes after a dictation, so the next one starts without opening Echo. Only after step 1.
5. Sign in with Apple and the App Store video header need Joshua's yes.

## Restart prompt
```
/loop until v4.0.0 for Echo (~/Documents/Code/echo): read docs/LOOP-HANDOFF.md first, work docs/roadmap.md top down, QA green before every push, tag and release each minor
```
