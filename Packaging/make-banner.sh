#!/bin/bash
# Regenerates docs/banner.png (the README hero banner). Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs
swift Packaging/render-banner.swift docs/banner.png \
  "note.text" "2BD0C4" "0E7C8C" \
  "GlassPad" "A translucent scratchpad, one keystroke away"
