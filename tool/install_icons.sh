#!/bin/sh
# Regenerates platform icons from assets/icon/icon_1024.png.
set -e
cd "$(dirname "$0")/.."
SRC=assets/icon/icon_1024.png
MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  sips -z $s $s "$SRC" --out "$MAC/app_icon_$s.png" >/dev/null
done
# Windows .ico with embedded PNGs (Vista+).
python3 - <<'PY'
import struct, subprocess, os, tempfile
sizes = [16, 24, 32, 48, 64, 128, 256]
imgs = []
for s in sizes:
    p = os.path.join(tempfile.gettempdir(), f"ico_{s}.png")
    subprocess.check_call(["sips", "-z", str(s), str(s), "assets/icon/icon_1024.png", "--out", p], stdout=subprocess.DEVNULL)
    imgs.append(open(p, "rb").read())
out = struct.pack("<HHH", 0, 1, len(imgs))
off = 6 + 16 * len(imgs)
for s, d in zip(sizes, imgs):
    out += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(d), off)
    off += len(d)
out += b"".join(imgs)
open("windows/runner/resources/app_icon.ico", "wb").write(out)
PY
