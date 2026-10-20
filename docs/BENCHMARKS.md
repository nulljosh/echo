# Benchmarks

Every engine Echo ships, on one clip. Measured, never estimated. Rerun after any engine change and replace the table.

## 2026-10-20, Mac mini M4

| Engine | Clip | Load | Transcribe | Faster than real time | Word error rate |
|---|---|---|---|---|---|
| Whisper tiny | `say` voice (16 s) | 3.6 s | 0.23 s | 70x | 0.0% |
| Whisper base | `say` voice (16 s) | 6.5 s | 0.32 s | 51x | 0.0% |
| Whisper small | `say` voice (16 s) | 0.5 s | 1.04 s | 15x | 0.0% |
| Apple SpeechAnalyzer | `say` voice (16 s) | 0.0 s | 0.23 s | 71x | 0.0% |
| Whisper tiny | Human, LibriVox (137 s) | 3.6 s | 1.38 s | 99x | 8.8% |
| Whisper base | Human, LibriVox (137 s) | 6.5 s | 1.99 s | 69x | 5.1% |
| Whisper small | Human, LibriVox (137 s) | 0.5 s | 6.25 s | 22x | 16.9% |
| Apple SpeechAnalyzer | Human, LibriVox (137 s) | 0.0 s | 1.65 s | 83x | 15.1% |

Best of two runs after a warm-up. Word error rate ignores case and punctuation; the LibriVox credit is trimmed off. 10 cores, 16 GB, macOS Version 27.0.1 (Build 26A434).

What it means: every engine is far faster than real time. On clean `say` speech all four are perfect. On a real human voice (a public domain LibriVox reading of the Gettysburg Address, 137 s) Whisper base was the most accurate at 5.1%, tiny 8.8%, Apple 15.1% and small 16.9%. Small and Apple doing worse than base is surprising; part of it may be how they write numbers and run-together words ("Fourscore", "battlefield") against this reference, which the error rate counts as misses. Checking that is on the roadmap before Auto's choices change. Apple stays first because it is fastest, needs no load and updates with the OS.

Small loaded in half a second only because this Mac had already compiled it; a first launch compiles for minutes on the Neural Engine, which is why tiny loads first on the GPU.

## Run it

```bash
TEST_RUNNER_VOXPRINT_BENCH=1 TEST_RUNNER_VOXPRINT_BENCH_OUT=/tmp/bench.md xcodebuild test -scheme VoxprintTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:VoxprintTests/BenchmarkTests
```
