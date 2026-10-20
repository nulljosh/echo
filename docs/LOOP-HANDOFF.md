# Echo loop handoff (2026-10-20, 11:25)

## What the loop is
The loop works Echo's ship path in this repo (ex-Notate, now nulljosh/echo at ~/Documents/Code/echo). Each tick does the next open step below, runs the QA gate and a cold-launch check before each commit, and pushes once QA is green. It stops when the landing, icon, brand kit and apps are A+ and the store name is Echo.

Always say Echo, never Voxprint or Notate, except where the store still says Notate. Replies short, TLDR, no em dashes.

## Where things stand
- v2.1.0 is tagged and released on GitHub after QA and a green CI run. Pushed. No App Store submission for it: Mac 2.0 is still WAITING_FOR_REVIEW.
- The repo and folder are nulljosh/echo and ~/Documents/Code/echo. Homepage is https://echo.jaybulb.com.
- Jony Ive pass on iPhone and Mac: native nav bar, record button in the centre, Settings beside it bottom-left, Liquid Glass button styles, the live word pops in, history uses native search, Settings is one Form. The splash and the record and file mode switch are gone.
- The landing demo iframe is removed and the site is redeployed at echo.jaybulb.com. notate.jaybulb.com still serves.
- License is Apache 2.0. Markdown except README and CLAUDE.md lives in docs/. README shortened, architecture.svg redrawn, LOC chart dropped.
- iPhone 2.0 with the Apple Watch companion is live. The store listing still says Notate until Mac 2.0 clears; the rename is roadmap item 9.
- Decided 2026-10-20 with Joshua, in docs/roadmap.md "Next": Apple SpeechTranscriber becomes the default engine with WhisperKit as the fallback; accounts become optional (Sign in with Apple or email via jaybulb-api, and the app works without one).
- GitHub issue sync for this repo is skipped on purpose. Its numbered roadmap items would be titled "8" and "9", and the UI items would duplicate existing issues under the new echo-*.png names.

## Next, in order
1. Build the two decided items from docs/roadmap.md "Next (decided 2026-10-20)": SpeechTranscriber first with WhisperKit fallback, then optional accounts. QA gate and cold launch before each commit.
2. Phone-width QA of echo.jaybulb.com: no horizontal scroll, 16px gutters, real tap targets.
3. Verify the Watch build (EchoWatch) still matches the new iPhone and Mac UI.
4. After Mac 2.0 clears review: asc rename the store listing to Echo (fallback Calliope). Read it back 3 times, then ship the Echo builds.
5. Joshua, not the loop: one real call in meeting mode on the Mac (roadmap item 28), and his grade for Dot v2 (roadmap item 29).

## Restart prompt
```
/loop until A+ landing page, icon and apps for Echo (ex-Notate): Hermes-style 1-bit ordered-dither landing in ~/Documents/Code/echo/docs, Echo icon, brand kit, rename sweep, builds green, deployed to echo.jaybulb.com
```
