# Notate loop handoff (2026-10-19, morning)

## What the loop is
One loop works the road to v2.0 in this repo, one roadmap item per tick. It reads `roadmap.md` ("Road to v2.0"), does the next open item, runs the QA gate and a cold-launch check before each commit, and pushes. It ships builds only when App Review allows. It stops at v2.0.

Always say Notate, never Voxprint. Replies short, TLDR, no em dashes.

## Where things stand
- iPhone 2.0 with the Apple Watch companion is live (READY_FOR_SALE, 2026-10-19). The app ships its models inside the bundle, so it opens and works offline. The download is 386 MB.
- Mac 2.0.0 is WAITING_FOR_REVIEW.
- The 2.0 landing is deployed to notate.jaybulb.com.
- Roadmap items 1 to 7 of "Road to v2.0" are checked off. Item 8 ("Ship 2.0 on iPhone, Watch and Mac") stays open until Mac clears.
- Check App Store state before acting on it: `asc versions list --app 6782604262`.

## Next, in order
1. Wait for Mac 2.0.0 approval.
2. When Mac 2.0.0 is READY_FOR_SALE, check item 8 off in `roadmap.md`, commit, push, and stop the loop.
3. Still open with Joshua, not the loop: one real call test of meeting mode (Mac, mic plus call audio, speaker labels), and his grade for Dot v2.

## Restart prompt
```
/loop Notate: work the road to v2.0 one item per tick (roadmap.md "Road to v2.0"), QA gate green + cold-launch check before each commit, ship builds when App Review allows, stop at v2.0
```
