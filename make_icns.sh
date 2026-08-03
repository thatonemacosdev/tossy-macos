#!/bin/bash
# Regenerates AppIcon.icns from the source PNGs in icons/.
# Run this after updating any icons/icon_*.png, then re-run build_app.sh.
set -euo pipefail

cd "$(dirname "$0")"

ICONSET=".iconset_tmp/AppIcon.iconset"
rm -rf "$(dirname "$ICONSET")"
mkdir -p "$ICONSET"

cp icons/icon_16.png   "$ICONSET/icon_16x16.png"
cp icons/icon_32.png   "$ICONSET/icon_16x16@2x.png"
cp icons/icon_32.png   "$ICONSET/icon_32x32.png"
cp icons/icon_64.png   "$ICONSET/icon_32x32@2x.png"
cp icons/icon_128.png  "$ICONSET/icon_128x128.png"
cp icons/icon_256.png  "$ICONSET/icon_128x128@2x.png"
cp icons/icon_256.png  "$ICONSET/icon_256x256.png"
cp icons/icon_512.png  "$ICONSET/icon_256x256@2x.png"
cp icons/icon_512.png  "$ICONSET/icon_512x512.png"
cp icons/icon_1024.png "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$(dirname "$ICONSET")"

echo "Wrote AppIcon.icns"
