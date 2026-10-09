#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) build/Cameo.app.
# ARCHS="arm64" scripts/build.sh builds one architecture only, for quicker local runs.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=${ARCHS:-"arm64 x86_64"}
BINARIES=()
for arch in $ARCHS; do
  swift build -c release --product Cameo --triple "$arch-apple-macosx14.0"
  BINARIES+=(".build/$arch-apple-macosx/release/Cameo")
done
swift build -c release --product CameoIcon
BIN=$(swift build -c release --show-bin-path)

APP=build/Cameo.app
ICONSET=build/AppIcon.iconset
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/Cameo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Strings tables, plus en.lproj so AppKit knows English is a language Cameo has.
cp -R Resources/Localizations/*.lproj "$APP/Contents/Resources/"
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
"$BIN/CameoIcon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Cameo"))"
