#!/usr/bin/env bash
# Builds release binaries and assembles build/Cameo.app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Cameo
swift build -c release --product CameoIcon
BIN=$(swift build -c release --show-bin-path)

APP=build/Cameo.app
ICONSET=build/AppIcon.iconset
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/Cameo" "$APP/Contents/MacOS/Cameo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
"$BIN/CameoIcon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
echo "Built $APP"
