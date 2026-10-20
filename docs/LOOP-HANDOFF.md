# Echo loop handoff (2026-10-20, afternoon)

## What the loop is
Joshua's brief, in his words: "to v4, 5-10 etc. Keep building roadmap. Keep updating benchmarks, improve efficiency and security and stability. Keep documentation 100%. Break up big god files." Subagents are allowed: one at a time, Haiku, in a worktree, on files the main loop is not touching.

Rules for every tick:
- One item from docs/roadmap.md per tick. QA gate green (`TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`) before every push. Mac and iOS both build.
- A batch of shipped items is a minor bump in `project.yml`, a tag and a GitHub release after CI is green. A major (v3.0) only for something keyboard-sized. Never filler versions.
- No App Store submission while Mac 2.0 is in review, and none without Joshua's yes.
- Build only what the roadmap holds. New ideas go to Joshua as one line, not into code.
- Docs stay 100%: every source file and doc has a row in docs/ARCHITECTURE.md, numbers are measured, never remembered.
- Any UI change: rerun `bash scripts/update_screenshots.sh`, look at the shots, commit them.
- Stop rule: read the usage hook every tick. At about 88% weekly, run /checkpoint, stop the loop, send one line.

## Where things stand
- v3.0.0 is the newest release: the Echo keyboard dictates into any app. Keyboards cannot use the mic, so its dictate key opens Echo, which records in the background, and the text comes back through `DictationBridge` (Darwin signals plus a shared Keychain group). Not yet walked on a real iPhone.
- v2.5.0: meetings on Apple with You and Them, Whisper base no longer ships (143 MB saved). v2.4.0: the bars, saved settings, the human voice benchmark (Apple 1.5% word error rate, small 1.9%, base 2.2%, tiny 6.0%).
- Signing: `com.nulljosh.echo.keyboard` registered; "Notate iOS App Store", "Notate Watch App Store" and "Echo Keyboard App Store" profiles regenerated in `signing/`. The ExportOptions plist must name all three.
- iPhone and Watch 2.0 live. Mac 2.0 waiting for review. The store listing still says Notate.
- Repo nulljosh/echo, folder ~/Documents/Code/echo, site https://echo.jaybulb.com (Pages project voxprint).
- Mac launch for demos: `-ApplePersistenceIgnoreState YES` must come before `-ECHO_DEMO 1`.

## Next, in order
1. Joshua walks the keyboard on a real iPhone: add it, allow Full Access, dictate into Messages, stop from the keyboard.
2. Keep the session warm for a few minutes after a dictation, so the next one starts without opening Echo.
3. After Mac 2.0 clears: store rename to Echo, read back 3 times. Sign in with Apple and the App Store video header need Joshua's yes. Submitting 3.0 to App Review needs his yes too.

## Restart prompt
```
/loop until v4.0.0 for Echo (~/Documents/Code/echo): read docs/LOOP-HANDOFF.md first, work docs/roadmap.md top down, QA green before every push, tag and release each minor
```
