#!/bin/bash
# Builds GlassPad.app into .build/. Run from anywhere: ./Packaging/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="GlassPad"
swift build -c release

APPDIR=".build/$APP.app"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
cp ".build/release/$APP" "$APPDIR/Contents/MacOS/$APP"
cp "Packaging/Info.plist" "$APPDIR/Contents/Info.plist"
[ -f "Packaging/$APP.icns" ] && cp "Packaging/$APP.icns" "$APPDIR/Contents/Resources/$APP.icns"

# Ad-hoc signature so launch services accepts the bundle (unsigned = Gatekeeper
# right-click-open on first run; documented in the README).
codesign --force --deep --sign - "$APPDIR" 2>/dev/null || true

echo "Built $APPDIR"
