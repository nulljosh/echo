# Echo loop handoff (2026-10-20, evening)

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
- v2.4.0 is the newest release: Mac bottom bar in one glass capsule, iPhone native bottom bar with same size icons (`BarIcon`), record button in the main view, saved model and language, the `-ECHO_DEMO 1` flag, and the human voice benchmark in docs/BENCHMARKS.md.
- Engine: Apple SpeechAnalyzer first, Whisper for meetings, custom words, older systems and other languages. TranscriptionEngine is split into +Models, +Live, +Apple, +Files.
- iPhone and Watch 2.0 live. Mac 2.0 waiting for review. The store listing still says Notate.
- Repo nulljosh/echo, folder ~/Documents/Code/echo, site https://echo.jaybulb.com (Pages project voxprint).
- Mac launch for demos: `-ApplePersistenceIgnoreState YES` must come before `-ECHO_DEMO 1`.

## Next, in order
1. Benchmarks: find why Whisper small and Apple trail base on the LibriVox clip. Print their text, normalize numbers and compounds, rerun.
2. v2.5, Apple part 2: meeting mode on Apple (two sessions, You and Them), then stop bundling base and small.
3. v3.0: the keyboard extension on iPhone, audio handed to the app to transcribe.
4. After Mac 2.0 clears: store rename to Echo, read back 3 times. Sign in with Apple and the App Store video header need Joshua's yes.

## Restart prompt
```
/loop until v3.0.0 for Echo (~/Documents/Code/echo): read docs/LOOP-HANDOFF.md first, work docs/roadmap.md top down, QA green before every push, tag and release each minor, v3.0 = dictation keyboard
```
