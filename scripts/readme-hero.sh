#!/usr/bin/env bash
# Renders the README's hero image, design/readme-hero.html, to docs/hero.jpg (2560×1440, 2x)
# with headless Google Chrome. Rerun after changing the page or the posters it shows.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
png=$(mktemp -t cameo-hero).png
"$CHROME" --headless=new --hide-scrollbars --force-device-scale-factor=2 \
  --window-size=1280,720 --screenshot="$png" "file://$PWD/design/readme-hero.html" 2>/dev/null
sips -s format jpeg -s formatOptions 85 "$png" --out docs/hero.jpg >/dev/null
rm -f "$png"
sips -g pixelWidth -g pixelHeight docs/hero.jpg | tail -2
