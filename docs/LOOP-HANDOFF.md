# Echo loop handoff (2026-10-20, midday)

## What the loop is
Joshua's brief, in his words: "to v4, 5-10 etc. Keep building roadmap. Keep updating benchmarks, improve efficiency and security and stability. Keep documentation 100%. Break up big god files." Subagents are allowed: one at a time, Haiku, in a worktree, on files the main loop is not touching.

Rules for every tick:
- One item from docs/roadmap.md per tick. QA gate green (`TEST_RUNNER_VOXPRINT_QA=1 xcodebuild test -scheme VoxprintTests ...`) before every push. Mac and iOS both build.
- A batch of shipped items is a minor bump in `project.yml`, a tag and a GitHub release after CI is green. A major (v3.0) only for something keyboard-sized. Never filler versions.
- No App Store submission while Mac 2.0 is in review, and none without Joshua's yes.
- Build only what the roadmap holds. New ideas go to Joshua as one line, not into code.
- Docs stay 100%: every source file and doc has a row in docs/ARCHITECTURE.md, numbers are measured, never remembered.
- Stop rule: read the usage hook every tick. At about 88% weekly, run /checkpoint, stop the loop, send one line.

## Where things stand
- v2.2.0 is tagged and released: Apple SpeechAnalyzer first with Whisper as fallback, optional accounts on jaybulb-api, new privacy policy and reset page. CI green, QA 19 tests green.
- iPhone and Watch 2.0 live. Mac 2.0 waiting for review. The store listing still says Notate.
- Repo nulljosh/echo, folder ~/Documents/Code/echo, site https://echo.jaybulb.com.

## Next, in order
1. Joshua's notes: What's New sheet overflow, duplicate voice names, a readable model list.
2. Hardening: refresh token Keychain item to ThisDeviceOnly; engine-level Apple test (stop while starting); Release cold launch now that launch requests Apple's model.
3. docs/BENCHMARKS.md: real-time factor for tiny, base, small and Apple on one `say` clip, opt-in test, machine and date.
4. Split TranscriptionEngine into extension files by area, no logic changes, QA between each.
5. Apple part 2: custom words through contextual strings, then meeting mode on Apple.
6. After Mac 2.0 clears: store rename to Echo, read back 3 times. Sign in with Apple needs Joshua's yes (Apple-side capability and new profiles).

## Restart prompt
```
/loop to v4,5-10 etc ultrathink 
Feel free to spawn subagents
Keep building roadmap etc
```
