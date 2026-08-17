# Voxprint (formerly Echo Transcription) Roadmap

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all — app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt** — that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Re-verified 2026-08-17: record still exists (`Transcriptly` / `com.nulljosh.echo.mac`), `asc web auth status` → `authenticated:false`. Unchanged.
  - **Expect the delete to refuse even once authenticated.** Lexly's identical duplicate-record deletion was attempted the same day with a valid web session and failed `409`: `CANNOT_REMOVE_WITH_APP_STORE_AVAILABILITY` + `IN_FLIGHT_REVIEW_SUBMISSIONS`. Transcriptly is `MAC_OS 9.9.9 REJECTED` and is one of the four apps named in the 5.6 suspension, so it likely carries both an availability record and a stuck submission too. Order that actually works: clear the review submission → remove App Store availability → *then* delete. All three are dashboard-only; `asc review submissions` has no cancel and `asc web apps availability` has no remove.
  - Apple support case **102949489427** (an earlier note cites 102949488998 — still unconfirmed which is live; can't check without the web session).

## After the 5.6 freeze lifts (2026-08-18)

**Both items below share one hard prerequisite — verified 2026-08-17.** There is no
editable version on record 6782604262. `asc versions list` returns 6 versions, *all*
`READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`; `asc validate --app 6782604262 --version
1.3.6 --platform IOS` returns 1 blocking error:

```
error  version.state.editable  version is in non-editable state "READY_FOR_DISTRIBUTION"
```

Screenshots attach to a version-localization, and the privacy URL lives on app-info —
both are locked outside an editable version. Neither is a metadata tweak that can be
done standalone: **a new version draft (1.3.7) must exist first**, which opens a release
cycle. Deliberately not created 2026-08-17 — the freeze was still on, there is no app
change to ship yet (the icon decision above is still open), and a half-populated draft
sitting in ASC is worse than none. Do these as part of the next real 1.3.7 release,
not before.

- [ ] Upload the regenerated App Store screenshots (`screenshots/appstore/`) — the
      live listing still shows Jul 3 captures with "Echo" branding. Shots 1/2/5 are
      current as of 2026-08-11; `3-paywall.png` and `4-settings.png` are still stale
      and need capturing (they require UI navigation, not just a launch argument).
      **Second prerequisite beyond the draft:** re-capture 3 + 4 first — uploading the
      current set would push two Echo-branded shots into a Voxprint listing.
- [ ] Migrate the App Store privacy URL to `https://echo.heyitsmejosh.com/privacy.html`.
      Currently held as the old `heyitsmejosh.com/echo/privacy.html`, which now works
      via a redirect in the portfolio repo. **Target URL verified 2026-08-17:** returns
      200 and serves Voxprint-branded content (the old one also still 200s, so this is
      a correctness/branding fix, not an outage). One `asc localizations update` call
      once a 1.3.7 draft exists.
