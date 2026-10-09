#!/usr/bin/env bash
# Cuts a release: scripts/release.sh 0.2.0
# Sets the version in Resources/Info.plist, commits, tags v<version> and pushes;
# the release workflow then builds the app and publishes it on GitHub Releases.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/release.sh <version, e.g. 0.2.0>}
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean" >&2; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo "release from main" >&2; exit 1; }
git rev-parse "v$VERSION" >/dev/null 2>&1 && { echo "tag v$VERSION already exists" >&2; exit 1; }

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
git commit -m "Release v$VERSION" Resources/Info.plist
git tag -a "v$VERSION" -m "Cameo $VERSION"
git push origin main "v$VERSION"
echo "Pushed v$VERSION; follow the release at https://github.com/wquguru/cameo/actions/workflows/release.yml"
