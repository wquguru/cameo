#!/usr/bin/env bash
# Publishes a character to the gallery: uploads the video to Cloudflare R2 (bucket
# cameo-characters, served at https://cameo.wqu.guru) and adds it to gallery/characters.json
# with a poster. Commit gallery/ afterwards to deploy the page.
# Usage: scripts/gallery-add.sh [--replace] <video.mov | package-folder | package.zip> <id> <name> <author> <category>
#   A character package (docs/package-spec.md) is checked, published as a clean <id>.zip and its
#   idle clip as <id>.mov, the gallery's preview.
#   author: "@handle" or a name; category: animal, person or other
#   An id names the character's share link (c/<id>/) for good: one already in the gallery is
#   refused unless --replace (same character, new video), and one in gallery/retired.json always.
# Needs wrangler logged in to the Cloudflare account (wrangler login), or
# CLOUDFLARE_API_TOKEN set to a token with R2 write access to the bucket.
set -euo pipefail
cd "$(dirname "$0")/.."

REPLACE=0
[[ ${1:-} == --replace ]] && { REPLACE=1; shift; }

FILE=${1:?usage: scripts/gallery-add.sh <video.mov> <id> <name> <author> <category>}
ID=${2:?missing id}
NAME=${3:?missing name}
AUTHOR=${4:?missing author}
CATEGORY=${5:?missing category: animal, person or other}
[[ $ID =~ ^[a-z0-9-]+$ ]] || { echo "id must be lowercase letters, digits and dashes"; exit 1; }
TAKEN=$(python3 -c 'import json, sys; ids = {e["id"] for e in json.load(open("gallery/characters.json"))}
retired = set(json.load(open("gallery/retired.json")))
print("retired" if sys.argv[1] in retired else "taken" if sys.argv[1] in ids else "")' "$ID")
[[ $TAKEN == retired ]] && { echo "id $ID was retired (gallery/retired.json); old share links may still point at it, pick another"; exit 1; }
[[ $TAKEN == taken && $REPLACE == 0 ]] && { echo "id $ID is already in the gallery; pick another, or pass --replace to give that character a new video"; exit 1; }

BUCKET=${CAMEO_BUCKET:-cameo-characters}
ORIGIN=${CAMEO_ASSETS:-https://cameo.wqu.guru}
URL="$ORIGIN/characters/$ID.mov"

# Uploads a file and confirms the public copy matches it.
put() {
    wrangler r2 object put "$BUCKET/characters/$(basename "$3")" --file "$1" --remote \
        --content-type "$2" --cache-control "public, max-age=86400"
    local downloaded
    downloaded=$(mktemp)
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 -o "$downloaded" "$3"
    [[ $(shasum -a 256 < "$1") == $(shasum -a 256 < "$downloaded") ]] || { echo "uploaded file does not match $3" >&2; exit 1; }
    rm -f "$downloaded"
    echo "Published $3"
}

PACKAGE=""
[[ -d $FILE ]] && PACKAGE=$FILE
[[ $FILE == *.zip ]] && PACKAGE=$(python3 scripts/character_package.py unpack "$FILE" "$(mktemp -d)")
if [[ -n $PACKAGE ]]; then
    swift scripts/character-check.swift "$PACKAGE" || { echo "the package fails the gallery's checks" >&2; exit 1; }
    ARCHIVE="$(mktemp -d)/$ID.zip"
    python3 scripts/character_package.py pack "$PACKAGE" "$ARCHIVE" "$ID"
    # Validates the idle clip and writes the poster and entry before anything is uploaded.
    swift scripts/gallery-entry.swift "$PACKAGE" "$ID" "$NAME" "$AUTHOR" "$URL" "$CATEGORY" "$ORIGIN/characters/$ID.zip"
    put "$(python3 scripts/character_package.py preview "$PACKAGE")" video/quicktime "$URL"
    put "$ARCHIVE" application/zip "$ORIGIN/characters/$ID.zip"
else
    # Validates the video and writes the poster and entry before anything is uploaded.
    swift scripts/gallery-entry.swift "$FILE" "$ID" "$NAME" "$AUTHOR" "$URL" "$CATEGORY"
    put "$FILE" video/quicktime "$URL"
fi
