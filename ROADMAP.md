# Echo Roadmap

## App Store Connect (2026-06-22)
- [ ] **Build upload failed ASC processing** (error code 90183, no detail text via API) — check the Apple validation email for the real reason, fix, then re-upload.
- [x] Support URL — `https://heyitsmejosh.com` is live (verified 200 via curl 2026-07-20), matches `AppStore.md`; no longer missing.

## Submission status (2026-05-30)
Code is done. Full paste-ready submission package: **`AppStore.md`**.
- [ ] Deploy portfolio so the privacy URL is live.
- [ ] In simulator: set scheme StoreKit Configuration to `Echo.storekit`, test buy + restore + the 3-free-file gate.
- [ ] macOS sandbox runtime smoke test (mic / model download into container / file import). Ship iOS first if this slips.

## iOS 1.3.0 rejection (2026-07-04)
Root cause found: 0 IAP products existed in ASC even though the app's paywall shipped referencing `com.nulljosh.echo.pro`. Created the non-consumable in ASC (`com.nulljosh.echo.unlock` — the `.pro` id was already permanently reserved from an earlier attempt), $7.99, review screenshot attached, code + `Echo.storekit` updated to match. IAP state is READY_TO_SUBMIT.
- [x] **Echo Mac MERGED into the iOS app record 2026-07-21** — corrected course after mistakenly submitting Echo Mac as its own separate app record (build 202607211549, canceled per Joshua: "no separate builds, all apps cross platform, one submission"). Root cause: `project.yml` was already set up correctly for Universal Purchase (both targets share `PRODUCT_BUNDLE_IDENTIFIER: com.nulljosh.echo`), but `Sources/macOS/Info.plist` had a **hardcoded** `CFBundleIdentifier` of `com.nulljosh.echo.mac` overriding it (since `GENERATE_INFOPLIST_FILE: NO`) — that's what silently routed uploads to the separate Mac app record instead of attaching to the iOS one. Fixed the hardcoded value to match iOS's pattern (`com.nulljosh.echo`), rebuilt (build 202607211558), and uploaded to the **iOS app ID (6782604262)** instead of the Mac one. Confirmed working: `asc versions create --app 6782604262 --platform MAC_OS` created a new macOS version record *under the same app record* as iOS — one app, two platforms. Filled in description/screenshot/subtitle for the new macOS localization. `asc review doctor` shows zero blockers. **Not yet submitted for review** — holding per plan until Joshua confirms the merge looks right in the dashboard.
- [ ] The old standalone "Echo Transcribe Mac" app record (id 6783015101) is now fully orphaned — needs Joshua to delete it via ASC dashboard (no public API to delete an app record, confirmed). Do not upload anything further to it.
- [ ] Same merge pattern (shared bundle ID + hardcoded-Info.plist check) should be applied to Talli and Epiphany next — not started, validate Echo's merge is solid first.
- [ ] Once availability is set, resubmit version 1.3.0 for review.

## 1.3.3 status check (2026-07-20)
Verified via `asc versions list --app 6782604262`: version 1.3.3 is **REJECTED** (appStoreState), not still "in review" as prior entries below implied. `asc versions view --include appStoreReviewDetail` returns only contact info, no rejection reason text — App Review's actual rejection message lives in Resolution Center, which has no public API (same dashboard-only wall as the ASC availability item above).
- [ ] **Manual step (Joshua, ASC dashboard only):** App Store Connect → Echo Transcription → 1.3.3 → Resolution Center — read the actual rejection reason, then fix + resubmit.

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
- [x] Submit iOS 1.3.3 for review — done 2026-07-19 (see line below); now REJECTED, see "1.3.3 status check" above.

## From Icons.pdf / Asc.pdf (imported 2026-07-12)
- [x] Echo 1.3.3 build submitted — confirmed via ASC API 2026-07-20; version state is REJECTED (rejection reason is dashboard-only, see above).
- [x] Added `UISupportsDocumentBrowser` to `Sources/iOS/Info.plist` (2026-07-20; `LSSupportsOpeningDocumentsInPlace` was already present, set false). Build verified via `xcodebuild build -scheme Echo-iOS -destination 'generic/platform=iOS Simulator'` — BUILD SUCCEEDED.
- [x] Echo Transcribe Mac 1.0 — verified via ASC API 2026-07-20: still PREPARE_FOR_SUBMISSION, matches the pricing blocker below (see "Stashed 2026-07-19").

- [ ] If 1.3.3 publish failed: asc publish appstore --app IOS_APP_ID --ipa .asc/artifacts/Echo-iOS.ipa --version 1.3.3 --wait --submit --confirm
  - note: publish failed — wrong app ID guess; get real ID via `asc apps list | grep -i echo` first (real iOS app ID: 6782604262, Mac: 6783015101)

## 2026-07-14 dump
- [x] Purchase flow was already fully wired (`StoreManager.purchase()` calls real StoreKit `product.purchase()`, `PaywallView` calls it) — the "greyed/dead" symptom was `isPro` being hardcoded `true` behind a `// ponytail: free launch, flip to false when IAP goes live` comment. IAP is now live/submitted, so flipped `isPro` to start `false` (2026-07-20), gating actually takes effect. Build verified.
- [x] What's New sheet: auto-size to text content — already implemented in `WhatsNewSheet.swift` via `GeometryReader`/`presentationDetents(.height(contentHeight))`, verified by code read 2026-07-20; no fixed oversized height found

## Speak-back + voices + paywall gating (requested 2026-07-14, stashed by wrap-up)
- [x] Speak transcript aloud via AVSpeechSynthesizer — new `Sources/Services/SpeechManager.swift`, play/stop button added to `TranscriptionView` (live transcript) and `HistoryRow` (past entries). Both Echo-iOS and Echo-macOS build clean (2026-07-21).
- [x] Voice picker in Settings: `VoicePicker` in `SettingsView.swift` lists `AVSpeechSynthesisVoice.speechVoices()` filtered to the device's current language, persists identifier to `UserDefaults` via `@AppStorage(SpeechManager.voiceIdentifierKey)`.
- [ ] Decide free/pro split — shipped ungated for now (`ponytail:` comment in `SpeechManager.swift` marks this as deferred to Joshua); revisit once a split is decided.
- [x] Mirrored on both Echo-iOS and Echo-macOS targets (shared SwiftUI code, no platform-specific branching needed).

## Stashed 2026-07-19
- [ ] Submit macOS 1.0 (app 6783015101): metadata DONE 2026-07-19; App Privacy published via asc web 2026-07-19; still blocked on pricing only — set Free in ASC dashboard then `asc review submit --app 6783015101 --version 1.0 --platform MAC_OS --build <latest> --confirm`
- [x] iOS 1.3.3 submitted for review 2026-07-19 (submission a632f6e0, build 11f70e89)

## ASC review findings 2026-07-20 (via Resolution Center)
- [ ] Guideline 2.1(b) App Completeness: "Unlock Echo Pro" IAP button greyed out/unresponsive in review. Root cause hypothesis (per Apple's own message): Paid Apps Agreement likely not in effect — needs bank/tax info added in ASC → Business → Agreements, Tax and Banking. No CLI/API path exists to check or fix this (dashboard-only, needs Joshua's real banking info). Paywall design confirmed by Joshua: 3-5 free transcriptions, then Pro unlocks unlimited for a few dollars via IAP.

## ASC review findings 2026-07-20 (via Resolution Center)
- [ ] Guideline 2.1(b) App Completeness: "Unlock Echo Pro" IAP button greyed out/unresponsive in review. Root cause hypothesis (per Apple's own message): Paid Apps Agreement likely not in effect — needs bank/tax info added in ASC → Business → Agreements, Tax and Banking. No CLI/API path exists to check or fix this (dashboard-only, needs Joshua's real banking info). Paywall design confirmed by Joshua: 3-5 free transcriptions, then Pro unlocks unlimited for a few dollars via IAP.
