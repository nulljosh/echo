# Echo loop handoff (2026-10-26, 00:30)

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
- iOS 3.0.0 is WAITING_FOR_REVIEW. It is the Echo keyboard (dictate key opens Echo, which records in the background; the text comes back through `DictationBridge`, Darwin signals plus a shared Keychain group) plus the glossary pass, where custom words also correct the transcript after Whisper. The glossary is commits 2b119bc and c4beb2a on main. The build was exported by hand with the three profiles, because ship-ios export fails on automatic signing.
- Mac 3.0.0 is submitted too (build 202610260028), waiting for review alongside iOS.
- The keyboard has not been walked on a real iPhone. The simulator cannot add the keyboard through iOS 27 Settings, so the walk has to be on a device.
- Mac 2.0 was last seen IN_REVIEW on 2026-10-20. Re-check it, the store listing still says Notate.
- v2.5.0: meetings on Apple with You and Them, Whisper base no longer ships (143 MB saved). v2.4.0: the bars, saved settings, the human voice benchmark (Apple 1.5% word error rate, small 1.9%, base 2.2%, tiny 6.0%).
- Signing: `com.nulljosh.echo.keyboard` registered; "Notate iOS App Store", "Notate Watch App Store" and "Echo Keyboard App Store" profiles regenerated in `signing/`. The ExportOptions plist must name all three.
- Repo nulljosh/echo, folder ~/Documents/Code/echo, site https://echo.jaybulb.com (Pages project voxprint).
- Mac launch for demos: `-ApplePersistenceIgnoreState YES` must come before `-ECHO_DEMO 1`.

## Next, in order
1. Joshua walks the keyboard on a real iPhone: add it, allow Full Access, dictate into Messages, stop from the keyboard.
2. Check Mac 3.0.0 with asc. Submitting it to App Review needs Joshua's yes.
3. Keep the session warm for a few minutes after a dictation, so the next one starts without opening Echo.
4. After Mac 2.0 clears: store rename to Echo, read back 3 times. Sign in with Apple and the App Store video header need Joshua's yes.

## Restart prompt
```
/loop until v4.0.0 for Echo (~/Documents/Code/echo): read docs/LOOP-HANDOFF.md first, work docs/roadmap.md top down, QA green before every push, tag and release each minor
```
