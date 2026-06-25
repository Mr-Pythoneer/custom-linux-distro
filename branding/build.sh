#!/usr/bin/env bash
#
# Rasterizes the SVG sources in branding/src/ to the PNGs Calamares branding
# expects (see iso/calamares/branding/crucibleos/branding.desc) and to a
# square favicon for the website.
#
# Built/verified on macOS using `qlmanage -t` (QuickLook's own thumbnail
# generator, ships with every macOS install) as the SVG rasterizer, since no
# CLI SVG renderer (rsvg-convert/inkscape/cairosvg) is installed here. Per
# this project's disk-as-cache rule, this script runs on whatever box has it
# checked out -- on a real Linux box, swap RASTERIZE() below for
# `rsvg-convert -w W -h H in.svg -o out.png`, which is the more standard tool
# there and doesn't need the letterbox-crop step this macOS path requires.
#
# qlmanage's thumbnailer always pads non-square input to a square canvas
# (white-letterboxed) at the requested size -- this script crops that back
# out by detecting the non-white band, rather than hand-coding crop offsets
# that would silently break if the source SVG's aspect ratio ever changes.
#
# Usage: ./build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/src"
OUT="$SCRIPT_DIR/out"
CALAMARES_DIR="$SCRIPT_DIR/../iso/calamares/branding/crucibleos"

mkdir -p "$OUT"

if ! command -v qlmanage >/dev/null 2>&1; then
    echo "build.sh: qlmanage not found -- this rasterization path is macOS-specific." >&2
    echo "On Linux, use: rsvg-convert -w W -h H src/X.svg -o out/X.png" >&2
    exit 1
fi

# Renders one SVG to an exact W x H PNG, auto-cropping qlmanage's square
# letterbox padding back out based on the SVG's own viewBox aspect ratio.
rasterize() {
    local svg="$1" width="$2" height="$3" out_name="$4"
    local square=$(( width > height ? width : height ))

    rm -f "$OUT/${out_name}.svg.png"
    qlmanage -t -s "$square" -o "$OUT" "$svg" >/dev/null

    PYW="$square" PYH="$height" PYTARGETW="$width" PYTARGETH="$height" \
    SRC_PNG="$OUT/$(basename "$svg").png" DEST_PNG="$OUT/$out_name" python3 -c '
import os
from PIL import Image

im = Image.open(os.environ["SRC_PNG"]).convert("RGBA")
square = im.size[0]
target_w = int(os.environ["PYTARGETW"])
target_h = int(os.environ["PYTARGETH"])

# Scale-to-fit within the square (qlmanage preserves aspect ratio, centers it),
# so the rendered content height within the square is square * (target_h/target_w)
# when target_w is the limiting dimension, else full square height.
if target_w >= target_h:
    content_h = round(square * (target_h / target_w))
    top = (square - content_h) // 2
    box = (0, top, square, top + content_h)
else:
    content_w = round(square * (target_w / target_h))
    left = (square - content_w) // 2
    box = (left, 0, left + content_w, square)

cropped = im.crop(box).resize((target_w, target_h), Image.LANCZOS)
cropped.save(os.environ["DEST_PNG"])
'
    rm -f "$OUT/$(basename "$svg").png"
    echo "Wrote $OUT/$out_name (${width}x${height})"
}

rasterize "$SRC/logo.svg" 512 512 "logo.png"
rasterize "$SRC/welcome.svg" 1024 460 "welcome.png"
rasterize "$SRC/logo.svg" 256 256 "favicon.png"

mkdir -p "$CALAMARES_DIR"
cp "$OUT/logo.png" "$CALAMARES_DIR/logo.png"
cp "$OUT/welcome.png" "$CALAMARES_DIR/welcome.png"
echo "Copied logo.png + welcome.png into $CALAMARES_DIR"

echo
echo "favicon.png is for docs/ (the website) -- copy it in manually if docs/index.html"
echo "gains a <link rel=\"icon\"> reference; not auto-wired since that's a website-content"
echo "decision, not a branding-asset one."
