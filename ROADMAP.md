# Echo Roadmap

## Next session (2026-05-30)
- [ ] Warm Xcode build of `Echo-macOS` and `Echo-iOS` to confirm StoreKit code compiles (cold WhisperKit build was too slow to finish 05-29).
- [ ] Set the scheme's StoreKit Configuration to `Echo.storekit`, run in simulator, test buy + restore + the 3-free-file gate.
- [ ] Confirm the small-model lock and Settings "Echo Pro" section render correctly on both platforms.

## Before App Store submission (needs Apple Developer account)
- [ ] Add `PrivacyInfo.xcprivacy` (declare: no tracking, no data collection — it is the selling point).
- [ ] Create the `com.nulljosh.echo.pro` non-consumable in App Store Connect at $7.99.
- [ ] Screenshots (use the `screenshot` skill) + App Store description. Hook: "On-device transcription you own. No subscription, no account, nothing leaves your iPhone."
- [ ] App Review note explaining on-device Whisper + the one-time unlock.

## Pricing (locked 2026-05-29)
$7.99 one-time, freemium with 3 free file transcriptions. Rationale and competitor data in memory `project_echo_monetization.md`.
