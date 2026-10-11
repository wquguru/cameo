#!/usr/bin/env bash
# Builds the app and packages it for release in build/:
#   Cameo-<version>-macOS-Universal.dmg   drag-to-Applications installer (recommended download)
#   Cameo-<version>-macOS-Universal.zip   the bare app
#   checksums.txt                         SHA-256 of both
set -euo pipefail
cd "$(dirname "$0")/.."

RELEASE=1 scripts/build.sh
ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" build/Cameo.app/Contents/Info.plist)
[[ "$ID" == io.github.wquguru.cameo ]] || { echo "Not a release build: $ID" >&2; exit 1; }
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

# The window layout is a Finder-made .DS_Store kept in the repo (scripts/dmg-template.sh), so
# packaging needs no Finder scripting and works in CI. The volume is always named "Cameo":
# the layout's background bookmark refers to the volume by name.
STAGE=build/dmg/stage
MOUNT=build/dmg/mount
rm -rf "$STAGE" "$MOUNT" build/dmg/rw.dmg
mkdir -p "$STAGE/.background" "$MOUNT"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp build/dmg/background.tiff "$STAGE/.background/background.tiff"
cp Resources/dmg/DS_Store "$STAGE/.DS_Store"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
hdiutil create -quiet -srcfolder "$STAGE" -volname Cameo -fs HFS+ -format UDRW -ov build/dmg/rw.dmg
hdiutil attach -quiet -readwrite -noverify -noautoopen -nobrowse -mountpoint "$MOUNT" build/dmg/rw.dmg
SetFile -a C "$MOUNT"
hdiutil detach -quiet "$MOUNT"
hdiutil convert -quiet build/dmg/rw.dmg -format UDZO -imagekey zlib-level=9 -ov -o "build/$NAME.dmg"

(cd build && shasum -a 256 "$NAME.dmg" "$NAME.zip" > checksums.txt)
echo "Packaged build/$NAME.dmg, build/$NAME.zip, build/checksums.txt"
