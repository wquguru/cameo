#!/usr/bin/env bash
# Builds build/Cameo.app and zips it as build/Cameo-<version>.zip.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
rm -f build/Cameo-*.zip
ditto -c -k --keepParent build/Cameo.app "build/Cameo-$VERSION.zip"
echo "Packaged build/Cameo-$VERSION.zip"
