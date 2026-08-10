# Voxprint (formerly Echo Transcription) Roadmap

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Dashboard-only — the API delete is refused while the version sits in a rejected state. Apple support case **102949489427** (an earlier note cites 102949488998 — confirm which is live). Joshua said 2026-07-29 he'd delete it from the ASC app-info screen himself. Check for an Apple reply, then retry `asc web apps delete --app 6783015101`, or delete via appstoreconnect.apple.com.

## From Apple Notes (imported 2026-08-08)
- [x] Website *content* still says Echo after the rename — STALE, already done in `fb47cab`. `web/index.html` has zero "Echo" hits and both echo./voxprint.heyitsmejosh.com serve the Voxprint copy live (verified 2026-08-09). Only leftover is the Cloudflare Pages project name `echo` (not user-facing).
