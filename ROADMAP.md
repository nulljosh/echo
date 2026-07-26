# Echo Roadmap

## App Store Connect (2026-06-22)
- [ ] **Build upload failed ASC processing** (error code 90183, no detail text via API) — check the Apple validation email for the real reason, fix, then re-upload.

## Submission status (2026-05-30)
Code is done. Full paste-ready submission package: **`AppStore.md`**.
- [ ] Deploy portfolio so the privacy URL is live.
- [ ] In simulator: set scheme StoreKit Configuration to `Echo.storekit`, test buy + restore + the 3-free-file gate.
- [ ] macOS sandbox runtime smoke test (mic / model download into container / file import). Ship iOS first if this slips.

## iOS 1.3.0 rejection (2026-07-04)
Root cause found: 0 IAP products existed in ASC even though the app's paywall shipped referencing `com.nulljosh.echo.pro`. Created the non-consumable in ASC (`com.nulljosh.echo.unlock` — the `.pro` id was already permanently reserved from an earlier attempt), $7.99, review screenshot attached, code + `Echo.storekit` updated to match. IAP state is READY_TO_SUBMIT.
- [ ] The old standalone "Echo Transcribe Mac" app record (id 6783015101) is now fully orphaned — needs Joshua to delete it via ASC dashboard (no public API to delete an app record, confirmed). Do not upload anything further to it.
- [ ] Same merge pattern (shared bundle ID + hardcoded-Info.plist check) should be applied to Talli and Epiphany next — not started, validate Echo's merge is solid first.
- [ ] Once availability is set, resubmit version 1.3.0 for review.

## 1.3.3 status check (2026-07-20)
Verified via `asc versions list --app 6782604262`: version 1.3.3 is **REJECTED** (appStoreState), not still "in review" as prior entries below implied. `asc versions view --include appStoreReviewDetail` returns only contact info, no rejection reason text — App Review's actual rejection message lives in Resolution Center, which has no public API (same dashboard-only wall as the ASC availability item above).
- [ ] **Manual step (Joshua, ASC dashboard only):** App Store Connect → Echo Transcription → 1.3.3 → Resolution Center — read the actual rejection reason, then fix + resubmit.

## The actual blocker (account-side, only Joshua)
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

## From Icons.pdf / Asc.pdf (imported 2026-07-12)

- [ ] If 1.3.3 publish failed: asc publish appstore --app IOS_APP_ID --ipa .asc/artifacts/Echo-iOS.ipa --version 1.3.3 --wait --submit --confirm
  - note: publish failed — wrong app ID guess; get real ID via `asc apps list | grep -i echo` first (real iOS app ID: 6782604262, Mac: 6783015101)

## Speak-back + voices + paywall gating (requested 2026-07-14, stashed by wrap-up)
- [ ] Decide free/pro split — shipped ungated for now (`ponytail:` comment in `SpeechManager.swift` marks this as deferred to Joshua); revisit once a split is decided.

## ASC review findings 2026-07-20 (via Resolution Center)
- [ ] Guideline 2.1(b) App Completeness: "Unlock Echo Pro" IAP button greyed out/unresponsive in review. Root cause hypothesis (per Apple's own message): Paid Apps Agreement likely not in effect — needs bank/tax info added in ASC → Business → Agreements, Tax and Banking. No CLI/API path exists to check or fix this (dashboard-only, needs Joshua's real banking info). Paywall design confirmed by Joshua: 3-5 free transcriptions, then Pro unlocks unlimited for a few dollars via IAP.

## ASC review findings 2026-07-20 (via Resolution Center)
- [ ] Guideline 2.1(b) App Completeness: "Unlock Echo Pro" IAP button greyed out/unresponsive in review. Root cause hypothesis (per Apple's own message): Paid Apps Agreement likely not in effect — needs bank/tax info added in ASC → Business → Agreements, Tax and Banking. No CLI/API path exists to check or fix this (dashboard-only, needs Joshua's real banking info). Paywall design confirmed by Joshua: 3-5 free transcriptions, then Pro unlocks unlimited for a few dollars via IAP.

## Ingested 2026-07-25
- [ ] Echo Mac — follow-up work needed (no further detail given).
- [ ] Splash screen / landing page still has cursive font — should match SF/Helvetica like other projects (epiphany etc). Never use cursive. Double-check all remaining projects landing pages for cursive too (sparkjar flagged specifically — see sparkjar/roadmap.md).
