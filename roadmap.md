# Voxprint (formerly Echo Transcription) Roadmap

## BLOCKED — IAP is built but switched off (Paid Apps Agreement)

Everything for Voxprint Pro already exists and is correct:
`Echo.storekit` defines `com.nulljosh.echo.unlock` as a **$7.99 non-consumable** (pricing
re-confirmed 2026-08-19 — keep it; "own it once, nothing leaves your device" is the pitch, so a
subscription would contradict the product), `PaywallView.swift` renders, `canTranscribeFile()`
enforces the 3-free-file gate, and `listenForTransactions()` is wired.

It is deliberately disabled in two places in `Sources/Services/StoreManager.swift`, both marked
with `ponytail:` comments explaining why:
- line ~19: `@Published private(set) var isPro = true` — hardcoded open
- `refreshEntitlement()`: stubbed to an early `return`

**Blocker: Apple is rejecting the bank account during payout enrollment.** This gates all IAP
revenue across every app. Apple's exact rejection reason is unknown (check ASC web UI → Business
→ Agreements); CRA business number involvement is uncertain but requires investigation. Phone queue
to CRA has been unresolved for weeks. Tracked in the wiki's `blocked-on-joshua.md` §3.

Once the account is enrolled: revert those two lines, rebuild, ship as v2. No other work required.
Stripe is irrelevant here — Voxprint has no server and no accounts, and Apple requires IAP for
unlocking in-app features regardless.

## 2026-08-18 — Echo Pro branding: IAP fixed, screenshots BLOCKED on toolchain

**Done:**
- **IAP renamed.** The ASC in-app purchase was still called "Echo Pro" — visible in the iOS purchase
  sheet and the listing's In-App Purchases section, independent of any screenshot. APPROVED records
  can't be edited in place, so created IAP version 2 (`b6820fe3-d079-4e71-8d2e-c7ead1be8fda`) and
  renamed localization `19ba7fbd-3900-4007-aed0-c8b4bb02a0df` to **"Voxprint Pro"**.
- **Fixed the silent-skip bug** in `UITests/PreviewScreenshot.swift`. `2-history` and `4-settings`
  wrapped their `snapshot()` calls in `if waitForExistence` guards, so a missed element skipped the
  capture without failing and left the stale file in place. That is how `3-paywall.png` and
  `4-settings.png` kept their pre-rename Jul 3 content while the pipeline exited 0. Both now assert.
- Cleaned "Echo Pro" from `AppStore.md` and `fastlane/metadata/en-US/release_notes.txt`; corrected the
  documented product id to the real `com.nulljosh.echo.unlock`.

**Not done — the screenshots are still stale.**

- [ ] **`fastlane snapshot` cannot extract images under Xcode 26.** Run 2026-08-18: the UI test itself
  **passed** (all five launches ran, the new assertions held, `Test Succeeded`), but the results table
  reported ❌ for both iPhone 11 Pro Max and iPhone 14 Plus and `fastlane/screenshots/en-US/` came out
  empty, so the `cp` step failed. Toolchain: **fastlane 2.238.0 + Xcode 26.6** — fastlane cannot parse
  the current `.xcresult` format, so it extracts zero attachments. Nothing is wrong with the app or
  the test.
  Options, cheapest first: (a) upgrade fastlane and retry; (b) drop fastlane and use
  `asc screenshots run` / `asc screenshots capture`, which drives simctl directly (see the
  `asc-shots-pipeline` skill); (c) extract the attachments from the `.xcresult` with `xcrun
  xcresulttool` in `scripts/update_screenshots.sh`.
- [ ] Once capture works: the listing fix needs a **new iOS version 1.3.7** — 1.3.6 is READY_FOR_SALE
  and ASC locks screenshots on a live version — plus a new build. Stage it, do not submit until the
  four in-flight review verdicts land.

## Bug 2026-08-18 — live app still shows "Echo Pro" branding

**Root cause is NOT stale screenshots.** The screenshots are accurate; the *app* renders the old name.
The paywall and Settings show "Echo Pro" because that string comes from **StoreKit**, and the IAP in
App Store Connect is still named "Echo Pro":

- IAP `6787371864`, productId `com.nulljosh.echo.unlock`, NON_CONSUMABLE, state **APPROVED**
- en-US localization `abdea9d9-8fda-4844-8470-d858f101e88b`, name **"Echo Pro"**, state APPROVED

So customers see "Unlock Echo Pro" in a purchase sheet for an app called Voxprint. Re-shooting the
screenshots would NOT have fixed this — it would just have re-photographed the same wrong string.

- [ ] Rename the IAP localization to "Voxprint Pro". `asc iap versions localizations update` is
  refused on the live record: *"Cannot edit InAppPurchaseLocalization"* in the APPROVED state. Same
  pattern as the Bookrank listing fix — it needs a **new IAP version** created first, which then
  carries the edit. Do that, then re-shoot the screenshots so both agree.
- [ ] Blocked with everything else until the updated Apple Developer Program License Agreement is
  accepted — metadata updates on existing apps are frozen until then.

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign — this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all — app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt** — that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Re-verified 2026-08-17: record still exists (`Transcriptly` / `com.nulljosh.echo.mac`), `asc web auth status` → `authenticated:false`. Unchanged.
  - **Expect the delete to refuse even once authenticated.** Lexly's identical duplicate-record deletion was attempted the same day with a valid web session and failed `409`: `CANNOT_REMOVE_WITH_APP_STORE_AVAILABILITY` + `IN_FLIGHT_REVIEW_SUBMISSIONS`. Transcriptly is `MAC_OS 9.9.9 REJECTED` and is one of the four apps named in the 5.6 suspension, so it likely carries both an availability record and a stuck submission too. Order that actually works: clear the review submission → remove App Store availability → *then* delete. All three are dashboard-only; `asc review submissions` has no cancel and `asc web apps availability` has no remove.
  - Re-verified 2026-08-19: unchanged, and now **proven to be pure dead weight** — `asc versions list` shows Voxprint `6782604262` already carries BOTH `IOS 1.3.6` and `MAC_OS 1.3.6` as `READY_FOR_SALE`, so nothing ships against `6783015101` / `com.nulljosh.echo.mac`. Deleting it cannot break a shipping app. Blocked again on the web session, but for a **new reason**: Apple's SRP signin endpoint returned `503` on three attempts (`web auth login failed: srp login failed: signin init failed with status 503`) — it fails *before* the 2FA step, so a verification code cannot get past it. Retry `asc-login` when Apple's endpoint recovers.
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

## From ASC session 2026-08-19
- [ ] **Delete orphan ASC record 6783015101 (Transcriptly, com.nulljosh.echo.mac).**
  Progress 2026-08-19: Apple's SRP 503 cleared, web session re-established. The
  in-flight-submission blocker is GONE — submission f9402460 was cancelled with
  `asc review submissions-update --id <id> --canceled=true --confirm` (this DOES
  work via CLI; the old "drafts are dashboard-only" note was wrong).
  Remaining blocker is only `STATE_ERROR.CANNOT_REMOVE_WITH_APP_STORE_AVAILABILITY`.
  `asc web apps availability` exposes only `create`, and `asc pricing availability
  edit` refuses to flip `--available-in-new-territories` on an existing record, so
  clearing availability looks genuinely dashboard-only: App Store Connect ->
  Transcriptly -> Pricing and Availability -> remove from sale in all territories.
  Then re-run:
  `asc web apps delete --app 6783015101 --expected-bundle-id com.nulljosh.echo.mac --expected-name "Transcriptly" --confirm`
  Safe to delete: Voxprint 6782604262 (com.nulljosh.echo) already ships MAC_OS
  1.3.6 READY_FOR_SALE, and deleting an app record does not unregister the bundle ID.
- [ ] Do the 'remove from sale in all territories' step via Claude in Chrome rather than by hand — Joshua OK'd browser automation for this on 2026-08-19. It is the one genuinely dashboard-only step: `asc web apps availability` exposes only `create`, so there is no CLI path. Once availability is cleared the delete command above works.
