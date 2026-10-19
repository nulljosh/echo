#!/bin/bash
# Fetches the Whisper models the app ships with into BundledModels/ so nothing downloads, ever offline.
# Runs as a pre-build step. Skips when the model is already complete. Not checked into git.
set -u
ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}/BundledModels"
status=0
for M in openai_whisper-tiny openai_whisper-base openai_whisper-small_216MB; do
DEST="$ROOT/$M"
[ -f "$DEST/.complete" ] && [ -f "$DEST/tokenizer.json" ] && continue
echo "Fetching $M into $DEST"
mkdir -p "$DEST"
python3 - "$DEST" "$M" <<'PY'
import json, os, sys, urllib.request
dest, folder = sys.argv[1], sys.argv[2]
repo = "argmaxinc/whisperkit-coreml"
tree = json.load(urllib.request.urlopen(f"https://huggingface.co/api/models/{repo}/tree/main/{folder}?recursive=true", timeout=60))
files = [i for i in tree if i["type"] == "file"]
for i in files:
    rel = i["path"].split(folder + "/", 1)[1]
    out = os.path.join(dest, rel)
    if os.path.exists(out) and os.path.getsize(out) == i["size"]: continue
    os.makedirs(os.path.dirname(out), exist_ok=True)
    urllib.request.urlretrieve(f"https://huggingface.co/{repo}/resolve/main/{i['path']}", out)
    if os.path.getsize(out) != i["size"]: raise SystemExit(f"size mismatch: {rel}")
# The tokenizer too, or WhisperKit fetches it from the internet on first launch.
size = folder.split("openai_whisper-", 1)[1].split("_")[0]  # small_216MB uses the small tokenizer
for name in ("tokenizer.json", "tokenizer_config.json"):
    out = os.path.join(dest, name)
    if not os.path.exists(out):
        urllib.request.urlretrieve(f"https://huggingface.co/openai/whisper-{size}/resolve/main/{name}", out)
open(os.path.join(dest, ".complete"), "w").write("ok")
print(f"fetched {len(files)} files")
PY
[ $? -ne 0 ] && status=1
done
if [ $status -ne 0 ]; then
  echo "warning: could not fetch the bundled models"
  # Release builds must carry them. Debug builds can go on without it, the app falls back to a download.
  [ "${CONFIGURATION:-Release}" = "Release" ] && exit 1
fi
exit 0
