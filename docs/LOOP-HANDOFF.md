# Notate loop handoff (2026-10-18, evening)

## What the loop is
One loop runs the App Store fix and ship work for the whole fleet, from this repo's seat because Notate is the next thing to build. It reads `~/.claude/projects/-Users-joshua/memory/project_asc_fix_loop_queue.md` (the LIVE PLAN at the top is the truth), does the next slice, updates that file and the `asc-status` skill, commits and pushes. The scheduled wakeups die with the session. The restart prompt at the bottom brings it back.

Always say Notate, never Voxprint. Replies short, TLDR, no em dashes.

## Where things stand
- Notate: iOS 1.4.1 is released and the store name is Notate, price $0.99. macOS 1.4.1 was in review at the last ASC check (2026-10-16). The App Store state was not re-checked in the 2026-10-18 checkpoint, so run `python3 ~/.claude/skills/asc-status/scripts/status.py` before acting on it.
- 1.4.2 is committed on main. The tiny, base and small speech models are packed inside the app, so nothing downloads on first run, and the icon is the new blue wave-to-text mark. A Release build needs `scripts/fetch-tiny-model.sh` to have run first, since Release fails without the model.
- Ship 1.4.2 after the Mac 1.4.1 review clears: bump the version and build number in project.yml, run the speech QA gate, archive iOS and macOS, upload, set What's New, submit.
- The fleet picture below dates from 2026-10-04 and was not re-verified in this checkpoint. Siftbox is now Mailbag and was resubmitted on 2026-10-18, so the old Pare rename plan is retired.
- Weekly usage: stop at 90 percent and report.
- Keep at least 6 GB free on the internal disk before heavy jobs. Builds and DerivedData go on /Volumes/LaCie.

## Next, in order
1. `asc-status`: new rejections or approvals first. Fix a rejection with the recipe in `~/.claude/skills/asc-status/SKILL.md`.
2. When Notate macOS 1.4.1 is approved, ship 1.4.2 (see above).
3. Re-run the fleet audit before the next release batch: `cd ~/Documents/Code && python3 ~/.claude/skills/fleet-audit/scripts/audit.py --asc`.
4. Notate keyboard (dictate into any app) is its own project, later. Icon direction for Notate is still Joshua's call.

## Gotchas learned
- Resubmit a rejected version with the same version string and a higher build number. Attach the build, resolve the rejected review item, then submit the old submission (the recipe is in the asc-status skill).
- asc web login: run `asc-login`. Joshua clicks Allow on Apple's dialog himself, never click it for him. The 2FA reader then reads the code off the screen. Wait 20 minutes between attempts.
- `asc xcode export` with the repo ExportOptions can upload straight to ASC and leave no local file. Check `asc builds list` before uploading again.
- xcodebuild test hangs on document-based app hosts (Plaintxt). Verify pure logic with swiftc instead. SwiftLint plugin validation needs `-skipPackagePluginValidation`.
- App Review replies and anything outward-facing need Joshua's yes in chat. Never run `sync`.
- Never launch visible apps or take full-screen screenshots, they can catch private tabs. Capture one window or use the simulator.

## Restart prompt
```
/loop Continue the App Store fix loop. Read ~/.claude/projects/-Users-joshua/memory/project_asc_fix_loop_queue.md. Only act if the weekly usage meter has reset (hook shows weekly_all below 50%) or Joshua has unblocked an item; then start Phase 2 (the fleet audit: read-only first, make a fleet-audit skill with a script) and check asc-status for new rejections or approvals. Otherwise do nothing and re-arm. Follow the queue rules. Stop and report at 90 percent weekly usage.
```
