#!/usr/bin/env bash
# Builds the app and packages it for release in build/:
#   Cameo-<version>-macOS-Universal.dmg   drag-to-Applications installer (recommended download)
#   Cameo-<version>-macOS-Universal.zip   the bare app
#   checksums.txt                         SHA-256 of both
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
NAME="Cameo-$VERSION-macOS-Universal"
APP=build/Cameo.app
rm -f build/Cameo-*.zip build/Cameo-*.dmg build/checksums.txt

ditto -c -k --keepParent "$APP" "build/$NAME.zip"

# Installer window background, drawn by the app itself at 1x and 2x.
rm -rf build/dmg && mkdir -p build/dmg
"$APP/Contents/MacOS/Cameo" --render-dmg-background build/dmg/background.png 1
"$APP/Contents/MacOS/Cameo" --render-dmg-background build/dmg/background@2x.png 2
tiffutil -cathidpicheck build/dmg/background.png build/dmg/background@2x.png -out build/dmg/background.tiff 2>/dev/null

# dmgbuild lays out the Finder window without scripting Finder, so it also works in CI.
if [[ ! -x build/.venv/bin/dmgbuild ]]; then
  python3 -m venv build/.venv
  build/.venv/bin/pip install --quiet "dmgbuild>=1.6,<2"
fi
build/.venv/bin/dmgbuild -s scripts/dmg-settings.py \
  -D app="$APP" -D background=build/dmg/background.tiff -D icon="$APP/Contents/Resources/AppIcon.icns" \
  "Cameo $VERSION" "build/$NAME.dmg"

(cd build && shasum -a 256 "$NAME.dmg" "$NAME.zip" > checksums.txt)
echo "Packaged build/$NAME.dmg, build/$NAME.zip, build/checksums.txt"
