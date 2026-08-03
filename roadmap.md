# Voxprint (formerly Echo Transcription) Roadmap

## Shipped
- [x] iOS 1.3.6 (Voxprint rename) — built, uploaded, submitted 2026-08-03. Build `202608031830` (id `250e6d44-dc13-4adc-948d-ba1351910d5f`), VALID, attached to version `e6cd1dcd-49ec-4633-b9d3-00cfe68513e2`, review submission `31fe0d40-eae5-4887-86b9-5f4234e48149` → **WAITING_FOR_REVIEW**. iOS 1.3.5 is now READY_FOR_SALE.
- [x] App Store description rewritten Echo → Voxprint. The v1.3.6 en-US description still named the app "Echo" throughout (including an "ECHO PRO" section) — the exact name App Review rejected. Rewritten to Voxprint plus a rename-focused What's New.

## Follow-ups (actionable, not blocked)
- [ ] macOS build still ships the old name. Mac 1.3.3 is READY_FOR_SALE but was archived before the rename commit (`8d8188e`), so the installed Mac app still shows "Echo". Needs a Mac version bump + `asc workflow run ship-mac VERSION:1.3.7`-style pass to match iOS. Note `.asc/workflow.json` has `MAC_APP_ID` incorrectly set to the iOS app id — both are `6782604262` (unified Universal Purchase record), so it happens to be right, but it reads like a copy-paste bug.
- [ ] `asc submission-health` referenced in old notes is NOT a real subcommand (it's a skill name). Real paths: `asc review status`, `asc review doctor`, `asc review submissions-list`.
- [ ] `asc review submit` is unreliable on this account — it failed with "review submission … does not contain target version" even though the submission *did* contain the version. Working sequence: `asc versions attach-build --version-id … --build-id …` then `asc review submissions-submit --id … --confirm`.

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Dashboard-only — the API delete is refused while the version sits in a rejected state. Apple support case **102949489427** (an earlier note cites 102949488998 — confirm which is live). Joshua said 2026-07-29 he'd delete it from the ASC app-info screen himself. Check for an Apple reply, then retry `asc web apps delete --app 6783015101`, or delete via appstoreconnect.apple.com.
- [ ] **Decide the marketing domain.** `voxprint.heyitsmejosh.com` does not resolve (curl → 000); `echo.heyitsmejosh.com` is live (200) and is still the App Store marketing URL for a product now named Voxprint. Either stand up the new subdomain (Cloudflare DNS + a Pages project, then `asc localizations update --version … --marketing-url …`) or accept the mismatch. Needs Joshua's call on whether the domain follows the rename.
