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
DEVICE="iPhone 18 Pro Max"      # 6.9 inch, the size App Store Connect asks for first
SIM_UDID="DBBE86E4-2B2D-4B76-B1A4-F2C01D586811"
SRC_DIR="$HOME/Library/Caches/tools.fastlane/screenshots"
SHOTS=("1-finished-transcript" "2-history" "3-summary" "4-settings" "5-live-recording")

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
  -project voxprint.xcodeproj \
  -scheme VoxprintUITests \
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

echo "==> Done: screenshots/appstore/ is fresh. Review and commit them yourself."
