# Echo Roadmap

## App Store Connect (2026-06-22)
- [ ] **Build upload failed ASC processing** (error code 90183, no detail text via API) — check the Apple validation email for the real reason, fix, then re-upload.
- [ ] Support URL still missing — required before submission.

## Submission status (2026-05-30)
Code is done. Full paste-ready submission package: **`AppStore.md`**.
- [ ] Deploy portfolio so the privacy URL is live.
- [ ] In simulator: set scheme StoreKit Configuration to `Echo.storekit`, test buy + restore + the 3-free-file gate.
- [ ] macOS sandbox runtime smoke test (mic / model download into container / file import). Ship iOS first if this slips.

## iOS 1.3.0 rejection (2026-07-04)
Root cause found: 0 IAP products existed in ASC even though the app's paywall shipped referencing `com.nulljosh.echo.pro`. Created the non-consumable in ASC (`com.nulljosh.echo.unlock` — the `.pro` id was already permanently reserved from an earlier attempt), $7.99, review screenshot attached, code + `Echo.storekit` updated to match. IAP state is READY_TO_SUBMIT.
- [ ] **Manual step (Joshua, ASC dashboard only — no safe public API path):** App Store Connect → Echo Transcription → Pricing and Availability → set territories (app availability is currently unset, blocks resubmission).
- [ ] Once availability is set, resubmit version 1.3.0 for review.

## The actual blocker (account-side, only Joshua)
- [x] Enroll Apple Developer Program — done, app is live.
- [x] Create app record `com.nulljosh.echo`, create IAP non-consumable at $7.99 — done 2026-07-04 (`com.nulljosh.echo.unlock`).
- [ ] Capture 5 iPhone screenshots (`screenshot` skill) per `AppStore.md`.
- [ ] App Privacy = Data Not Collected, paste privacy URL, archive + upload, submit.

## Pricing (locked 2026-05-29)
$7.99 one-time, freemium with 3 free file transcriptions. Rationale and competitor data in memory `project_echo_monetization.md`.

## From Echo Transcribe.pdf (imported 2026-06-28)
- [ ] Onboarding: add Echo logo more prominently around the app
- [ ] Onboarding: let user choose Whisper model on first load
- [ ] Onboarding: request all permissions on first load

## From icons-bugs.pdf (imported 2026-06-30)
- [ ] Mac app broken — needs investigation (Mac icon source fixed 2026-06-30, new Mac build/upload still needed — may be the same issue)

## From Echo web.pdf (imported 2026-07-01)
- [x] Web app icon was stale — icon.svg + navbar icon now match the shipped black/white icon (2026-07-04)
- [x] No real landing page — `docs/index.html` is now a marketing page (hero, features, CTA to App Store + app), functional app moved to `docs/app.html` unchanged (2026-07-04)

## Stashed 2026-06-21

## From Echo.pdf (imported 2026-07-12)
- [ ] Submit iOS 1.3.3 for review: run `asc workflow run ship-ios VERSION:1.3.3` (blocked: App Store submission needs user approval outside auto mode; plist + download-UX fixes already committed in 9be1314, build verified)

## From Icons.pdf / Asc.pdf (imported 2026-07-12)
- [ ] Echo 1.3.3 PREPARE_FOR_SUBMISSION — confirm b9 paywall-fix build submitted (per Asc.pdf)
- [ ] Add LSSupportsOpeningDocumentsInPlace or UISupportsDocumentBrowser to Info.plist next build (non-blocking)
- [ ] Echo Transcribe Mac 1.0 — verify Mac build upload, then submit
