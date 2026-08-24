#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Regenerating Xcode project"
xcodegen generate

# The UITest writes PNGs straight to the HOST's fastlane cache dir (SnapshotHelper
# resolves SIMULATOR_HOST_HOME, not the simulator's own filesystem), named
# "<device>-<shot>.png". We drive xcodebuild directly and read them from there.
#
# We do NOT use `fastlane snapshot`: fastlane 2.238.0 cannot parse Xcode 26's
# .xcresult format, so its extraction step yields zero images and still exits 0.
# The capture itself was never broken -- only fastlane's post-processing was.
DEVICE="Voxprint-Shots"          # dedicated iPhone 14 Plus (1284x2778, 6.7")
SIM_UDID="267C51B7-E068-4A9A-8870-9B66A2B16412"
SRC_DIR="$HOME/Library/Caches/tools.fastlane/screenshots"
SHOTS=("1-finished-transcript" "2-history" "3-paywall" "4-settings" "5-live-recording")

# Capture is only trustworthy if every PNG is newer than this marker -- a partial
# run leaves stale files on disk and would otherwise silently ship old images.
RUN_MARKER="$(mktemp -t voxprint-shots)"
# bash's -nt compares mtimes at 1s granularity, so back the marker off a second
# to avoid false "stale" on a same-second write. A real run takes minutes.
touch -A -01 "$RUN_MARKER"
trap 'rm -f "$RUN_MARKER"' EXIT

echo "==> Booting $DEVICE"
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null

echo "==> Pinning status bar (9:41, full bars, charged)"
xcrun simctl status_bar "$SIM_UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

echo "==> Running UI test (mock data, no real recordings needed)"
xcodebuild test \
  -project echo.xcodeproj \
  -scheme EchoUITests \
  -destination "id=$SIM_UDID" \
  -skipPackagePluginValidation \
  | tail -5

echo "==> Verifying all ${#SHOTS[@]} screenshots were actually regenerated"
stale=0
for shot in "${SHOTS[@]}"; do
  src="$SRC_DIR/${DEVICE}-${shot}.png"
  if [[ ! -f "$src" ]]; then
    echo "    MISSING: $src" >&2
    stale=1
  elif [[ ! "$src" -nt "$RUN_MARKER" ]]; then
    echo "    STALE (left over from an earlier run): $src" >&2
    stale=1
  fi
done
if (( stale )); then
  echo "==> FAILED: the UI test did not produce a fresh set of screenshots." >&2
  echo "    Nothing was copied or committed. See roadmap.md." >&2
  exit 1
fi

echo "==> Copying screenshots into screenshots/appstore"
mkdir -p screenshots/appstore
for shot in "${SHOTS[@]}"; do
  cp "$SRC_DIR/${DEVICE}-${shot}.png" "screenshots/appstore/${shot}.png"
done

# The landing page hero uses these same two shots -- refresh them here so the
# site can't drift out of sync with the app again (it did across the rename).
echo "==> Refreshing web hero shots"
cp "$SRC_DIR/${DEVICE}-1-finished-transcript.png" web/assets/shot-1.png
cp "$SRC_DIR/${DEVICE}-5-live-recording.png" web/assets/shot-2.png

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

Regenerated via xcodebuild UI test using mock data (UITEST_RECORDING/FINISHED/
HISTORY/PAYWALL launch arguments) -- no real audio/transcription required.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"

echo "==> Pushing"
git push

echo "==> Done"
