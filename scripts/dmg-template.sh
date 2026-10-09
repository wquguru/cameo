#!/usr/bin/env bash
# Regenerates Resources/dmg/DS_Store, the installer window layout, by letting Finder lay out a
# scratch volume. Run it on a Mac (it scripts Finder) after changing the window size, icon
# positions or background path; keep them in sync with Sources/Cameo/DMGBackground.swift.
# Finder writes both the legacy (pBBk) and macOS 26 (pBB0) background bookmarks, which
# third-party .DS_Store writers miss, so the result shows the background on old and new macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d build/Cameo.app && -f build/dmg/background.tiff ]] || { echo "run scripts/package.sh first" >&2; exit 1; }
WORK=build/dmg-template
rm -rf "$WORK" && mkdir -p "$WORK/stage/.background"
cp -R build/Cameo.app "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"
cp build/dmg/background.tiff "$WORK/stage/.background/background.tiff"
hdiutil create -quiet -srcfolder "$WORK/stage" -volname Cameo -fs HFS+ -format UDRW -size 40m "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$WORK/rw.dmg"

# Window 720 x 440 of content (468 with the title bar); icons at the background's marks.
osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "Cameo"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 920, 588}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Cameo.app" of container window to {190, 200}
    set position of item "Applications" of container window to {530, 200}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
cp /Volumes/Cameo/.DS_Store Resources/dmg/DS_Store
hdiutil detach /Volumes/Cameo -quiet
echo "Updated Resources/dmg/DS_Store"
