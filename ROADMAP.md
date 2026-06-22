# Echo Roadmap

## Submission status (2026-05-30)
Code is done. Full paste-ready submission package: **`AppStore.md`**.
- [x] iOS Release build verified: **BUILD SUCCEEDED** (signing aside).
- [x] `PrivacyInfo.xcprivacy` bundled both targets, `ITSAppUsesNonExemptEncryption=false`.
- [x] Device family set to iPhone-only ("1") -- halves screenshot work.
- [x] Privacy policy written: `nulljosh.github.io/echo/privacy.html` -> https://heyitsmejosh.com/echo/privacy.html (deploy portfolio to make live).
- [x] All listing copy, keywords, description, review notes drafted in `AppStore.md`.
- [ ] Deploy portfolio so the privacy URL is live.
- [ ] In simulator: set scheme StoreKit Configuration to `Echo.storekit`, test buy + restore + the 3-free-file gate.
- [ ] macOS sandbox runtime smoke test (mic / model download into container / file import). Ship iOS first if this slips.

## The actual blocker (account-side, only Joshua)
- [ ] Enroll Apple Developer Program ($99 USD/yr). Gates everything below + every App Store dollar.
- [ ] Create app record `com.nulljosh.echo`, create `com.nulljosh.echo.pro` non-consumable at $7.99.
- [ ] Capture 5 iPhone screenshots (`screenshot` skill) per `AppStore.md`.
- [ ] App Privacy = Data Not Collected, paste privacy URL, archive + upload, submit.

## Pricing (locked 2026-05-29)
$7.99 one-time, freemium with 3 free file transcriptions. Rationale and competitor data in memory `project_echo_monetization.md`.

## Stashed 2026-06-21
- [ ] macOS `AppIcon.appiconset` (`Sources/macOS/Assets.xcassets/AppIcon.appiconset/`) is missing its 1024x1024 icon — only goes up to 512x512 currently. Export 1024 from repo-root `icon.svg`, add the `mac` idiom 1024 entry to `Contents.json`. This is why App Store Connect shows a placeholder icon for the "Echo Transcribe" listing.
