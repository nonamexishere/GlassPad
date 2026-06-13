#!/bin/bash
# Regenerates Packaging/GlassPad.icns from an SF Symbol. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="GlassPad"
SYMBOL="note.text"
TOP="2BD0C4"
BOTTOM="0E7C8C"

TMP="$(mktemp -d)"
ICONSET="$TMP/$APP.iconset"
mkdir -p "$ICONSET"

swift Packaging/render-icon.swift "$TMP/base.png" "$SYMBOL" "$TOP" "$BOTTOM"

for sz in 16 32 64 128 256 512 1024; do
  sips -z $sz $sz "$TMP/base.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
done

# Build the @2x names the iconset spec expects, then drop the non-spec sizes.
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"

iconutil -c icns "$ICONSET" -o "Packaging/$APP.icns"
rm -rf "$TMP"
echo "wrote Packaging/$APP.icns"
