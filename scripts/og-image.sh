#!/usr/bin/env bash
# Renders the gallery's social card, design/og-card.html, to gallery/og.png (1200×630)
# with headless Google Chrome. Rerun after changing the card or the poster it shows.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1200,630 --screenshot="$PWD/gallery/og.png" "file://$PWD/design/og-card.html" 2>/dev/null
sips -g pixelWidth -g pixelHeight gallery/og.png | tail -2
