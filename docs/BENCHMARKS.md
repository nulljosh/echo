# Benchmarks

Every engine Echo ships, on one clip. Measured, never estimated. Rerun after any engine change and replace the table.

## 2026-10-20, Mac mini M4

| Engine | Load | Transcribe | Faster than real time | Word error rate |
|---|---|---|---|---|
| Whisper tiny | 3.8 s | 0.28 s | 57x | 0% |
| Whisper base | 6.3 s | 0.32 s | 51x | 0% |
| Whisper small | 0.5 s | 1.03 s | 16x | 0% |
| Apple SpeechAnalyzer | 0.0 s | 0.25 s | 65x | 0% |

Clip: 16.1 s of `say` speech, 16 kHz. Best of two runs after a warm-up. 10 cores, 16 GB, macOS Version 27.0.1 (Build 26A434).

What it means: Apple's SpeechAnalyzer is the fastest and needs no load, which is why Auto picks it on iOS and macOS 26. Whisper small is the most accurate Whisper on real voices and still 16 times faster than real time. Small loaded in half a second here only because this Mac had already compiled it; a first launch compiles for minutes on the Neural Engine, which is why tiny loads first on the GPU.

Limits: `say` speech is clean, so every engine scores 0% here. Real voices, accents and noise separate them. A recorded human clip is the next step for the word error column.

## Run it

```bash
TEST_RUNNER_VOXPRINT_BENCH=1 TEST_RUNNER_VOXPRINT_BENCH_OUT=/tmp/bench.md xcodebuild test -scheme VoxprintTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:VoxprintTests/BenchmarkTests
```
