#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Regenerating Xcode project"
xcodegen generate

echo "==> Running fastlane snapshot (mock data, no real recordings needed)"
fastlane snapshot

DEVICE="iPhone 17 Pro"
SHOTS=("1-live-recording" "2-finished-transcript" "3-history" "4-paywall" "5-settings")

echo "==> Copying screenshots into screenshots/appstore"
mkdir -p screenshots/appstore
for shot in "${SHOTS[@]}"; do
  cp "fastlane/screenshots/en-US/${DEVICE}-${shot}.png" "screenshots/appstore/${shot}.png"
done

echo "==> Staging screenshots + README"
git add -f screenshots/appstore/*.png
git add README.md

if git diff --cached --quiet; then
  echo "==> No changes to commit"
  exit 0
fi

echo "==> Committing"
git commit -m "$(cat <<'EOF'
Update Echo App Store screenshots

Regenerated via fastlane snapshot using mock data (UITEST_RECORDING/FINISHED/
HISTORY/PAYWALL launch arguments) -- no real audio/transcription required.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"

echo "==> Pushing"
git push

echo "==> Done"
