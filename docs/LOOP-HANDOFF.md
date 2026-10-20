# Echo loop handoff (2026-10-20, 11:00)

## What the loop is
The loop works the Echo rename and its ship path in this repo (ex-Notate). Each tick does the next open step below, runs the QA gate and a cold-launch check before each commit, and pushes only once QA is green. It stops when the landing, icon, brand kit and apps are A+ and the store name is Echo.

Always say Echo, never Voxprint or Notate, except where the store still says Notate. Replies short, TLDR, no em dashes.

## Where things stand
- The Echo landing is live at echo.jaybulb.com: Hermes-style page, black and white ordered-dither art from public domain paintings, system font. notate.jaybulb.com still serves.
- The icon is a voice wave that settles into a written line, in blue #0074D9. Brand kit: brand/BRAND.md and docs/brand.html.
- Mac and iOS builds are green on the current tree.
- iPhone 2.0 with the Apple Watch companion is live. Mac 2.0.0 is WAITING_FOR_REVIEW.
- The store listing still says Notate. Both app infos are locked (the live one and the Mac 2.0 review), so the store rename waits. It is roadmap item 9.
- The rename commits (618669e, ab2c825) are on GitHub. The handoff commit above the roadmap queue is local only; hold it until the QA test suite is green, then push.
- The checkpoint skipped the GitHub issue sync for this repo. The numbered roadmap items 8 and 9 would have been titled "8" and "9", and the UI items would have duplicated issues 31, 32 and 35 under their new echo-*.png names.

## Next, in order
1. QA tests green, then push the local handoff commit.
2. gh repo rename echo; git remote set-url origin to the new repo URL; gh repo edit --homepage https://echo.jaybulb.com.
3. Move the folder from notate to echo under ~/Documents/Code and fix every path that points at notate (Xcode project paths, scripts, docs).
4. Verify the Watch build (EchoWatch).
5. Phone-width QA of echo.jaybulb.com: no horizontal scroll, 16px gutters, real tap targets.
6. After Mac 2.0 clears review: asc rename the store listing to Echo (fallback Calliope). Read it back 3 times, then ship the Echo builds.
7. Still with Joshua, not the loop: one real call in meeting mode on the Mac (roadmap item 28), and his grade for Dot v2 (roadmap item 29).

## Restart prompt
```
/loop until A+ landing page, icon and apps for Echo (ex-Notate): Hermes-style 1-bit ordered-dither landing in ~/Documents/Code/notate/docs, Echo icon, brand kit, rename sweep, builds green, deployed to echo.jaybulb.com
```
