# Echo whitepaper

**v2.2.0** · October 2026

Speech to text that never leaves your device.

Cloud transcription sends every recording through someone else's server before it becomes text. That is a bad trade for anything personal, and on-device models are now good enough that the round trip buys nothing. Echo transcribes on iPhone, Mac and Apple Watch with no network call.

## How it listens

`TranscriptionEngine` owns everything. It runs WhisperKit on the device, batching live audio every 2 seconds and decoding only what came after the last finished segment, so a one hour recording stays as quick as a short one and nothing said is ever dropped. The word being heard right now is lit in the accent. When you stop, it goes over the recording once more for the final text.

Tiny, base and small ship inside the app, so the first launch works offline in seconds. Tiny loads first and small swaps in between recordings. A broken model is wiped and Echo falls back to tiny instead of showing an error. The 1.3.9 release bricked phones without this, and the QA test now breaks a model on purpose to prove it heals.

On iOS 26 and macOS 26, Apple's own SpeechAnalyzer comes first. Echo asks the system to install Apple's model for your language in the background, and once it is there, live speech and files run through it: faster, long-form, and kept up to date by Apple. Whisper takes over on older systems, in Mac meetings (it labels You and Them), when you have custom words (it is the model that takes a prompt), for the languages Apple does not know, and whenever Apple's session fails to start.

## What it adds

- **Meetings on the Mac.** The mic and what the Mac plays (ScreenCaptureKit) are transcribed side by side and labelled You and Them. No bot joins the call.
- **Custom words.** Names and jargon from Settings become Whisper prompt tokens, capped at 50.
- **Clean up and summary.** Apple's on-device Foundation Models fix punctuation and filler words, and write a summary with action items. Offered only where the system model exists.
- **Everywhere.** Shortcuts and the Action button start a recording. The Watch records on its own and the iPhone transcribes it.

## Privacy

No audio or text leaves the device, and there are no analytics. An account is optional: it keeps a name, an email and a password hash on jaybulb-api (Cloudflare), with sign out and delete in Settings. `PrivacyInfo.xcprivacy` ships in every target, the Mac app runs in the App Sandbox, and `ITSAppUsesNonExemptEncryption` is false.

## Platforms

iOS 17 and macOS 14 in SwiftUI from one source tree, one App Store record with Universal Purchase. watchOS records on its own. Versions live only in `project.yml`.

Apache 2.0. Copyright 2026 Joshua Trommel.
