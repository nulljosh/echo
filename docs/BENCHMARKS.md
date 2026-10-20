# Benchmarks

Every engine Echo ships, on one clip. Measured, never estimated. Rerun after any engine change and replace the table.

## 2026-10-20, Mac mini M4

| Engine | Clip | Load | Transcribe | Faster than real time | Word error rate |
|---|---|---|---|---|---|
| Whisper tiny | `say` voice (16 s) | 10.6 s | 0.22 s | 72x | 0.0% |
| Whisper base | `say` voice (16 s) | 15.6 s | 0.32 s | 51x | 0.0% |
| Whisper small | `say` voice (16 s) | 0.5 s | 1.02 s | 16x | 0.0% |
| Apple SpeechAnalyzer | `say` voice (16 s) | 0.0 s | 0.22 s | 74x | 0.0% |
| Whisper tiny | Human, LibriVox (137 s) | 10.6 s | 1.34 s | 102x | 6.0% |
| Whisper base | Human, LibriVox (137 s) | 15.6 s | 1.99 s | 69x | 2.2% |
| Whisper small | Human, LibriVox (137 s) | 0.5 s | 6.24 s | 22x | 1.9% |
| Apple SpeechAnalyzer | Human, LibriVox (137 s) | 0.0 s | 1.54 s | 89x | 1.5% |

Best of two runs after a warm-up. Word error rate ignores case and punctuation; the LibriVox credit is trimmed off. 10 cores, 16 GB, macOS Version 27.0.1 (Build 26A434).

What it means: every engine is far faster than real time. On clean `say` speech all four are perfect. On a real human voice (a public domain LibriVox reading of the Gettysburg Address, 137 s) Apple is the most accurate at 1.5%, then small 1.9%, base 2.2% and tiny 6.0%. So Auto's order holds: Apple first, small as the Whisper target, tiny only to start fast. The reference uses modern spellings ("battlefield", "cannot"), and the scorer finds the speech by "score and seven", since engines write the first word as "Four", "For" or "Fourscore". An earlier run missed that and counted the reading's spoken credit as errors for small and Apple.

Load times vary run to run with what else the Neural Engine is doing. Small loaded in half a second only because this Mac had already compiled it; a first launch compiles for minutes on the Neural Engine, which is why tiny loads first on the GPU.

## Run it

```bash
TEST_RUNNER_VOXPRINT_BENCH=1 TEST_RUNNER_VOXPRINT_BENCH_OUT=/tmp/bench.md xcodebuild test -scheme VoxprintTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:VoxprintTests/BenchmarkTests
```
