# Voxprint (formerly Echo Transcription) Roadmap

## Shipped 2026-08-10
- [x] **iOS 1.3.6 RELEASED — now `READY_FOR_SALE`.** It had been sitting in `PENDING_DEVELOPER_RELEASE` since Apple approved it (version created 2026-07-29); the macOS 1.3.6 twin went live 2026-08-03 and the iOS half was simply never released. Shipped with `asc versions release --version-id e6cd1dcd-49ec-4633-b9d3-00cfe68513e2 --confirm`, verified via `asc versions list`. **Both platforms are now live on 1.3.6.** Note for next time: `PENDING_DEVELOPER_RELEASE` means Apple is done and only a one-command release is left — check for it before assuming an app is still "in review".

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all — app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt** — that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Apple support case **102949489427** (an earlier note cites 102949488998 — still unconfirmed which is live; can't check without the web session).

## From Apple Notes (imported 2026-08-08)
- [x] Website *content* still says Echo after the rename — STALE, already done in `fb47cab`. `web/index.html` has zero "Echo" hits and both echo./voxprint.heyitsmejosh.com serve the Voxprint copy live (verified 2026-08-09). Only leftover is the Cloudflare Pages project name `echo` (not user-facing).
