#!/usr/bin/env bash
# Publishes a character to the gallery: uploads the video to Cloudflare R2 (bucket
# cameo-characters, served at https://cameo.wqu.guru) and adds it to gallery/characters.json
# with a poster. Commit gallery/ afterwards to deploy the page.
# Usage: scripts/gallery-add.sh [--replace] <video.mov> <id> <name> <author> <category>
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
KEY="characters/$ID.mov"
URL="$ORIGIN/$KEY"

# Validates the video and writes the poster and entry before anything is uploaded.
swift scripts/gallery-entry.swift "$FILE" "$ID" "$NAME" "$AUTHOR" "$URL" "$CATEGORY"

wrangler r2 object put "$BUCKET/$KEY" --file "$FILE" --remote \
    --content-type video/quicktime --cache-control "public, max-age=86400"

# Confirm the public copy matches the local file.
DOWNLOADED=$(mktemp)
curl -fsSL --retry 5 --retry-all-errors --retry-delay 3 -o "$DOWNLOADED" "$URL"
[[ $(shasum -a 256 < "$FILE") == $(shasum -a 256 < "$DOWNLOADED") ]] || { echo "uploaded file does not match $URL" >&2; exit 1; }
rm -f "$DOWNLOADED"
echo "Published $URL"
