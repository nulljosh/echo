# Voxprint (formerly Echo Transcription) Roadmap

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all — app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt** — that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Apple support case **102949489427** (an earlier note cites 102949488998 — still unconfirmed which is live; can't check without the web session).

## After the 5.6 freeze lifts (2026-08-18)
- [ ] Upload the regenerated App Store screenshots (`screenshots/appstore/`) — the
      live listing still shows Jul 3 captures with "Echo" branding. Shots 1/2/5 are
      current as of 2026-08-11; `3-paywall.png` and `4-settings.png` are still stale
      and need capturing (they require UI navigation, not just a launch argument).
- [ ] Migrate the App Store privacy URL to `https://echo.heyitsmejosh.com/privacy.html`.
      Currently held as the old `heyitsmejosh.com/echo/privacy.html`, which now works
      via a redirect in the portfolio repo. `asc localizations update` rejects the
      field while the app-info is locked outside an editable version.
