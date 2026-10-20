# Echo whitepaper

**v2.1.0** · October 2026

Speech to text that never leaves your device.

Cloud transcription sends every recording through someone else's server before it becomes text. That is a bad trade for anything personal, and on-device models are now good enough that the round trip buys nothing. Echo transcribes on iPhone, Mac and Apple Watch with no network call.

## How it listens

`TranscriptionEngine` owns everything. It runs WhisperKit on the device, batching live audio every 2 seconds and decoding only what came after the last finished segment, so a one hour recording stays as quick as a short one and nothing said is ever dropped. The word being heard right now is lit in the accent. When you stop, it goes over the recording once more for the final text.

Tiny, base and small ship inside the app, so the first launch works offline in seconds. Tiny loads first and small swaps in between recordings. A broken model is wiped and Echo falls back to tiny instead of showing an error. The 1.3.9 release bricked phones without this, and the QA test now breaks a model on purpose to prove it heals.

On iOS 26 and macOS 26, Apple's own SpeechAnalyzer can transcribe files when its model for the language is installed. Making it the default for live speech, with Whisper as the fallback, is the next engine step (see the roadmap).

## What it adds

- **Meetings on the Mac.** The mic and what the Mac plays (ScreenCaptureKit) are transcribed side by side and labelled You and Them. No bot joins the call.
- **Custom words.** Names and jargon from Settings become Whisper prompt tokens, capped at 50.
- **Clean up and summary.** Apple's on-device Foundation Models fix punctuation and filler words, and write a summary with action items. Offered only where the system model exists.
- **Everywhere.** Shortcuts and the Action button start a recording. The Watch records on its own and the iPhone transcribes it.

## Privacy

No audio or text leaves the device. No account, no analytics. `PrivacyInfo.xcprivacy` ships in every target, the Mac app runs in the App Sandbox, and `ITSAppUsesNonExemptEncryption` is false.

## Platforms

iOS 17 and macOS 14 in SwiftUI from one source tree, one App Store record with Universal Purchase. watchOS records on its own. Versions live only in `project.yml`.

Apache 2.0. Copyright 2026 Joshua Trommel.
