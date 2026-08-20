#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Regenerating Xcode project"
xcodegen generate

# Must match fastlane/Snapfile's devices() list and the UITest snapshot names
DEVICE="iPhone 14 Plus"
SHOTS=("1-finished-transcript" "2-history" "3-paywall" "4-settings" "5-live-recording")

# fastlane exits 0 even when it extracts zero attachments from the .xcresult, and
# stale PNGs from a previous run are still on disk -- so "cp succeeded" proves
# nothing. Gate on freshness: every shot must be newer than this marker.
RUN_MARKER="$(mktemp -t voxprint-shots)"
# bash's -nt compares mtimes at 1s granularity, so back the marker off a second
# to avoid false "stale" on a same-second write. A real run takes minutes.
touch -A -01 "$RUN_MARKER"
trap 'rm -f "$RUN_MARKER"' EXIT

echo "==> Running fastlane snapshot (mock data, no real recordings needed)"
fastlane snapshot

echo "==> Verifying all ${#SHOTS[@]} screenshots were actually regenerated"
stale=0
for shot in "${SHOTS[@]}"; do
  src="fastlane/screenshots/en-US/${DEVICE}-${shot}.png"
  if [[ ! -f "$src" ]]; then
    echo "    MISSING: $src" >&2
    stale=1
  elif [[ ! "$src" -nt "$RUN_MARKER" ]]; then
    echo "    STALE (left over from an earlier run): $src" >&2
    stale=1
  fi
done
if (( stale )); then
  echo "==> FAILED: fastlane reported success but did not produce fresh screenshots." >&2
  echo "    Known cause: fastlane 2.238.0 cannot parse Xcode 26.6 .xcresult files." >&2
  echo "    Nothing was copied or committed. See roadmap.md." >&2
  exit 1
fi

echo "==> Copying screenshots into screenshots/appstore"
mkdir -p screenshots/appstore
for shot in "${SHOTS[@]}"; do
  cp "fastlane/screenshots/en-US/${DEVICE}-${shot}.png" "screenshots/appstore/${shot}.png"
done

# The landing page hero uses these same two shots -- refresh them here so the
# site can't drift out of sync with the app again (it did across the rename).
echo "==> Refreshing web hero shots"
cp "fastlane/screenshots/en-US/${DEVICE}-1-finished-transcript.png" web/assets/shot-1.png
cp "fastlane/screenshots/en-US/${DEVICE}-5-live-recording.png" web/assets/shot-2.png

echo "==> Staging screenshots + README"
git add -f screenshots/appstore/*.png web/assets/shot-1.png web/assets/shot-2.png
git add README.md

if git diff --cached --quiet; then
  echo "==> No changes to commit"
  exit 0
fi

echo "==> Committing"
git commit -m "$(cat <<'EOF'
Update Voxprint App Store screenshots

Regenerated via fastlane snapshot using mock data (UITEST_RECORDING/FINISHED/
HISTORY/PAYWALL launch arguments) -- no real audio/transcription required.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"

echo "==> Pushing"
git push

echo "==> Done"
