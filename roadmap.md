# Voxprint (formerly Echo Transcription) Roadmap

## BLOCKED, IAP is built but switched off (Paid Apps Agreement)

Everything for Voxprint Pro already exists and is correct:
`Echo.storekit` defines `com.nulljosh.echo.unlock` as a **$7.99 non-consumable** (pricing
re-confirmed 2026-08-19, keep it; "own it once, nothing leaves your device" is the pitch, so a
subscription would contradict the product), `PaywallView.swift` renders, `canTranscribeFile()`
enforces the 3-free-file gate, and `listenForTransactions()` is wired.

It is deliberately disabled in two places in `Sources/Services/StoreManager.swift`, both marked
with `ponytail:` comments explaining why:
- line ~19: `@Published private(set) var isPro = true`, hardcoded open
- `refreshEntitlement()`: stubbed to an early `return`

**Blocker: Apple is rejecting the bank account during payout enrollment.** This gates all IAP
revenue across every app. Apple's exact rejection reason is unknown (check ASC web UI → Business
→ Agreements); CRA business number involvement is uncertain but requires investigation. Phone queue
to CRA has been unresolved for weeks. Tracked in the wiki's `blocked-on-joshua.md` §3.

Once the account is enrolled: revert those two lines, rebuild, ship as v2. No other work required.
Stripe is irrelevant here, Voxprint has no server and no accounts, and Apple requires IAP for
unlocking in-app features regardless.

## 2026-08-18, Echo Pro branding: IAP fixed, screenshots BLOCKED on toolchain

**Done:**
- **IAP renamed.** The ASC in-app purchase was still called "Echo Pro", visible in the iOS purchase
  sheet and the listing's In-App Purchases section, independent of any screenshot. APPROVED records
  can't be edited in place, so created IAP version 2 (`b6820fe3-d079-4e71-8d2e-c7ead1be8fda`) and
  renamed localization `19ba7fbd-3900-4007-aed0-c8b4bb02a0df` to **"Voxprint Pro"**.
- **Fixed the silent-skip bug** in `UITests/PreviewScreenshot.swift`. `2-history` and `4-settings`
  wrapped their `snapshot()` calls in `if waitForExistence` guards, so a missed element skipped the
  capture without failing and left the stale file in place. That is how `3-paywall.png` and
  `4-settings.png` kept their pre-rename Jul 3 content while the pipeline exited 0. Both now assert.
- Cleaned "Echo Pro" from `AppStore.md` and `fastlane/metadata/en-US/release_notes.txt`; corrected the
  documented product id to the real `com.nulljosh.echo.unlock`.

**Not done, the screenshots are still stale.**

## Bug 2026-08-18, live app still shows "Echo Pro" branding (RESOLVED 2026-08-24)

**Root cause was NOT stale screenshots.** The screenshots were accurate; the *app* rendered the old name.
The paywall and Settings showed "Echo Pro" because that string came from **StoreKit**, and the IAP in
App Store Connect was named "Echo Pro":

- IAP `6787371864`, productId `com.nulljosh.echo.unlock`, NON_CONSUMABLE, state **APPROVED**
- en-US localization `abdea9d9-8fda-4844-8470-d858f101e88b`, name **"Echo Pro"**, state APPROVED

## Blocked on Joshua
- [ ] **Icon direction decision.** Current blue mic mark (clrs.cc #0074D9) reads generic. Needs Joshua's call on the new direction before any redesign, this is a taste/design judgement, not something to guess at. No command; just a decision, then the icon regen + a version bump to ship it.
- [ ] **Delete the duplicate Mac ASC record `6783015101` ("Echo Transcribe Mac" / now listed as "Transcriptly", macOS 9.9.9 Developer Rejected).** Re-verified 2026-08-10: the record **still exists** and is still `MAC_OS 9.9.9 REJECTED`.
  - The public API genuinely cannot do this. Deleting its only version fails with `The request cannot be fulfilled because of the state of another resource.: The last version of an app cannot be deleted.`, and `asc apps` has no delete subcommand at all, app-record deletion only exists as `asc web apps delete`.
  - `asc web` needs an Apple web session; `asc web auth status` returns `{"authenticated":false,"passwordStored":true}`. Re-auth is `asc-login`, which drives Apple's **interactive 2FA prompt**, that needs Joshua at the keyboard with a device to hand. This is the actual wall, not the rejected-version state.
  - **Exactly what to do:** run `asc-login`, enter the 2FA code, then `asc web apps delete --app 6783015101`. If that still refuses, delete via appstoreconnect.apple.com → Transcriptly → App Information → Remove App.
  - Re-verified 2026-08-17: record still exists (`Transcriptly` / `com.nulljosh.echo.mac`), `asc web auth status` → `authenticated:false`. Unchanged.
  - **Expect the delete to refuse even once authenticated.** Lexly's identical duplicate-record deletion was attempted the same day with a valid web session and failed `409`: `CANNOT_REMOVE_WITH_APP_STORE_AVAILABILITY` + `IN_FLIGHT_REVIEW_SUBMISSIONS`. Transcriptly is `MAC_OS 9.9.9 REJECTED` and is one of the four apps named in the 5.6 suspension, so it likely carries both an availability record and a stuck submission too. Order that actually works: clear the review submission → remove App Store availability → *then* delete. All three are dashboard-only; `asc review submissions` has no cancel and `asc web apps availability` has no remove.
  - Re-verified 2026-08-19: unchanged, and now **proven to be pure dead weight**, `asc versions list` shows Voxprint `6782604262` already carries BOTH `IOS 1.3.6` and `MAC_OS 1.3.6` as `READY_FOR_SALE`, so nothing ships against `6783015101` / `com.nulljosh.echo.mac`. Deleting it cannot break a shipping app. Blocked again on the web session, but for a **new reason**: Apple's SRP signin endpoint returned `503` on three attempts (`web auth login failed: srp login failed: signin init failed with status 503`), it fails *before* the 2FA step, so a verification code cannot get past it. Retry `asc-login` when Apple's endpoint recovers.
  - Apple support case **102949489427** (an earlier note cites 102949488998, still unconfirmed which is live; can't check without the web session).

## After the 5.6 freeze lifts (2026-08-18)

**Both items below share one hard prerequisite, verified 2026-08-17.** There is no
editable version on record 6782604262. `asc versions list` returns 6 versions, *all*
`READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`; `asc validate --app 6782604262 --version
1.3.6 --platform IOS` returns 1 blocking error:

```
error  version.state.editable  version is in non-editable state "READY_FOR_DISTRIBUTION"
```

Screenshots attach to a version-localization, and the privacy URL lives on app-info , 
both are locked outside an editable version. Neither is a metadata tweak that can be
done standalone: **a new version draft (1.3.7) must exist first**, which opens a release
cycle. Deliberately not created 2026-08-17, the freeze was still on, there is no app
change to ship yet (the icon decision above is still open), and a half-populated draft
sitting in ASC is worse than none. Do these as part of the next real 1.3.7 release,
not before.

## From ASC session 2026-08-19
- [ ] **Delete orphan ASC record 6783015101 (Transcriptly, com.nulljosh.echo.mac).**
  Progress 2026-08-19: Apple's SRP 503 cleared, web session re-established. The
  in-flight-submission blocker is GONE, submission f9402460 was cancelled with
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
- [ ] Do the 'remove from sale in all territories' step via Claude in Chrome rather than by hand, Joshua OK'd browser automation for this on 2026-08-19. It is the one genuinely dashboard-only step: `asc web apps availability` exposes only `create`, so there is no CLI path. Once availability is cleared the delete command above works.

## Ingested 2026-08-22
- [ ] Remove the "downloading model" step on first launch, bundle the model with the app instead. From Notes: "Opening the app and waiting for the model to download is infuriatingly wasting time." Check the model's on-disk size against App Store limits before committing to bundling.

## 2026-08-23, delete the Transcriptly ASC record
Transcriptly (ASC 6783015101, com.nulljosh.echo.mac) is the old Voxprint-for-Mac record,
superseded by Voxprint macOS 1.3.6 (Ready for Distribution). It is stuck at 9.9.9 Rejected
and there is no CLI or self-serve delete for a record that has been submitted.
- [ ] Ask Apple Developer Support to delete app record 6783015101 (bundle in the same request as Lexly Mac 6783501927 and Nullfolio 6788180394).

### 2026-08-23, ship-ios publish step fixed (workflow.json is gitignored)
`.asc/` is gitignored so this fix is local-only; recorded here to survive a reclone.
`ExportOptions.plist` sets `destination=upload`, so the export step uploads to ASC itself and
writes no local `.asc/artifacts/echo.ipa`. The publish step's
`asc publish appstore --ipa ...` therefore always failed with "failed to stat IPA" *after* a
successful upload. Replaced with
`asc review submit --app $IOS_APP_ID --version $VERSION --platform IOS --confirm --output json`.
Found by hitting the identical bug in curvely. Untested here, voxprint 1.3.6 is already live,
so it will not be exercised until the next version bump.

## From /work start (imported 2026-08-24)

- [ ] **macOS 1.3.7, DO NOT SHIP IT AS-IS. Re-scoped 2026-08-25 after checking what would actually be in it.** `git log --since=2026-08-06 -- Sources/` returns **zero commits**, so a macOS 1.3.7 build would be a functionally identical binary with a bumped version number. iOS 1.3.7's changes were *listing* fixes (screenshots, privacy link), not app code, which is why the shared `MARKETING_VERSION: "1.3.7"` in `project.yml` makes macOS merely *look* behind. Shipping it would add another record to the review queue and invite a no-significant-changes flag for zero user benefit. **Ship macOS only when a real Mac-side change exists**, and fold the one cosmetic gap in at that point: macOS `marketingUrl` is still the pre-rename `echo.` host while iOS uses `https://voxprint.heyitsmejosh.com`. Both return 200, so nothing is broken and it is not worth a release of its own. Original note follows:
      it now reads 1.3.7 while ASC still has MAC_OS 1.3.6 READY_FOR_SALE. Only the iOS listing needed
      the screenshot/privacy fix, so the Mac side was deliberately left alone, but the next Mac build
      archived from this tree will carry 1.3.7. Either ship `asc workflow run ship-mac VERSION:1.3.7`
      or accept the skew knowingly.
- [ ] **Mac screenshots still thin**, `screenshots/macos/` has exactly one shot (`01-main.png`,
      dated 2026-08-03). Same capture trick should work for `EchoMacUITests`, but macOS has no
      SnapshotHelper host-cache path; needs its own approach (Quotestreak used
      `CGWindowListCopyWindowInfo`). Not attempted.
- **CLOSED 2026-08-25** (stale, `asc iap list --app 6782604262` now reports `com.nulljosh.echo.unlock` as **APPROVED**, not PREPARE_FOR_SUBMISSION. Note the paywall is still hardcoded open in `Sources/Services/StoreManager.swift` because the Paid Apps Agreement is unsigned; the IAP being approved does not unblock revenue). Was: **IAP version 2 rides along with a version submission.** `b6820fe3` is PREPARE_FOR_SUBMISSION and
      was NOT added to review submission `0d7dc8e9`, the 1.3.7 submission carries only the version item.
      If the "Echo Pro" string in the live purchase sheet matters, the IAP version has to be attached to
      a review submission explicitly (`asc review items-add`) on the next release.

## iOS 1.3.8 is a staged draft, do not submit it alone

Created 2026-08-28 only to unfreeze the app-info record so the privacy URL could be corrected
to `https://voxprint.heyitsmejosh.com/privacy.html` (verified by re-pull). No build, no
whatsNew, zero code changes behind it. A no-significant-changes review during the 4.3(a) wave
is a bad trade, attach it to the next real change, and fold in the macOS `marketingUrl`,
still on the pre-rename host, at the same time.

## The site does not deploy on push

`voxprint.heyitsmejosh.com` is a proxied CNAME to the Cloudflare **Pages** project `voxprint`,
with no git integration. Deploy explicitly:

    env -u CLOUDFLARE_API_TOKEN npx wrangler pages deploy docs --project-name voxprint --branch main

`CLOUDFLARE_DNS_TOKEN` is DNS-scoped and **overrides** the working OAuth login if exported , 
that is what made an earlier deploy fail with "Failed to automatically retrieve account IDs".
Worth wiring the Pages project to build from this repo so a push is enough.

## Open

- [ ] Apple Watch companion app -- standalone watchOS target (XcodeGen), same pattern as talli/watchos, sparkjar/watchos, epiphany/watchos, and the new companions in bookrank/charwork/curvely/fengshui/inkpress/lexly/quotestreak. Deferred 2026-09-02 to keep the sweep scoped; pick network+token-pairing, App-Group share, or a fully local port depending on what the app actually is.
