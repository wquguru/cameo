#!/usr/bin/env bash
# Publishes a character to the gallery: uploads the video to the "characters" release and
# adds it to gallery/characters.json with a poster. Commit gallery/ afterwards to deploy.
# Usage: scripts/gallery-add.sh <video.mov> <id> <name> <author> <category>
#   author: "@handle" or a name; category: animal, person or other
set -euo pipefail
cd "$(dirname "$0")/.."

FILE=${1:?usage: scripts/gallery-add.sh <video.mov> <id> <name> <author> <category>}
ID=${2:?missing id}
NAME=${3:?missing name}
AUTHOR=${4:?missing author}
CATEGORY=${5:?missing category: animal, person or other}
[[ $ID =~ ^[a-z0-9-]+$ ]] || { echo "id must be lowercase letters, digits and dashes"; exit 1; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
URL="https://github.com/$REPO/releases/download/characters/$ID.mov"
swift scripts/gallery-entry.swift "$FILE" "$ID" "$NAME" "$AUTHOR" "$URL" "$CATEGORY"

# A separate release that never becomes "latest", so the app's update check ignores it.
gh release view characters >/dev/null 2>&1 ||
    gh release create characters --title "Characters" --notes "Videos for the Cameo character gallery." --latest=false
TMP=$(mktemp -d)
cp "$FILE" "$TMP/$ID.mov"
gh release upload characters "$TMP/$ID.mov" --clobber
rm -rf "$TMP"
echo "Published $URL"
