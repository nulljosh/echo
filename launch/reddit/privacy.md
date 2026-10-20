Note: no karma minimum posted, but check current standing. Some privacy subs are stricter about anything that looks like an ad, keep it story-first. Public launch.

Title: Made a transcription app where the audio genuinely never leaves the device

Body:
I kept running into dictation apps that claimed to be private but still sent the audio to a server to actually transcribe it. That's not private, that's just a privacy policy. So I built Echo to run Whisper directly on iPhone and Mac, no network call at all.

Everything happens locally via WhisperKit and CoreML. No account, no analytics, nothing uploaded, ever. It works with no internet connection once the model is downloaded, which also means it works on a plane or anywhere else offline.

Everything is included in one $0.99 payment: live mic transcription, file transcription, all unlimited, no recurring charge to track.

Genuinely curious if anyone here has audited on-device ML apps for privacy leaks I might have missed (telemetry, crash reporting, etc).

https://echo.jaybulb.com
