# Voxprint (formerly Echo Transcription) Roadmap

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all — app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt** — that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Apple support case **102949489427** (an earlier note cites 102949488998 — still unconfirmed which is live; can't check without the web session).

## Echo→Voxprint rename, remaining (2026-08-10)
- [ ] Regenerate `web/assets/shot-1.png` / `shot-2.png` — hero mockups on
      voxprint.heyitsmejosh.com still show "Echo" in the phone title bar.
      Captured 14 Jul, pre-rename. App source already renders "Voxprint"
      (Sources/Views/ContentView.swift:239), so a fresh sim capture is the
      whole fix: shot-1 = finished transcript, shot-2 = mid-record (red stop).
      Overwrite at the same filenames, then `wrangler pages deploy web
      --project-name echo`.
- [ ] AppStore.md:8,69 lists the privacy URL as
      https://heyitsmejosh.com/echo/privacy.html — that 404s. The live,
      Voxprint-branded page is https://echo.heyitsmejosh.com/privacy.html.
      Verify which URL App Store Connect actually holds and repoint if needed.
- Done: docs/ site (GitHub Pages, echo.heyitsmejosh.com) fully renamed.
- Deliberately skipped: project.yml target/scheme names, .ship.json,
  bundle id com.nulljosh.echo — internal only, no user-visible impact.
