#!/usr/bin/env bash
# Turns a green-screen clip (e.g. from an AI video tool) into an HEVC-with-alpha .mov for Cameo.
# Usage: greenscreen.sh in.mp4 [out.mov]
# Env:   KEY=auto|0xRRGGBB  key colour (auto samples the first frame's top-left corner)
#        SIMILARITY=0.12    how far from the key colour still counts as background
#        BLEND=0.06         softness of the edge
#        CROP=auto|none|W:H:X:Y  auto crops to the figure over the whole clip, feet on the bottom edge
#        HEIGHT=720         output height in pixels
set -euo pipefail

IN=${1:?usage: greenscreen.sh in.mp4 [out.mov]}
OUT=${2:-${IN%.*}-alpha.mov}
KEY=${KEY:-auto}
SIMILARITY=${SIMILARITY:-0.12}
BLEND=${BLEND:-0.06}
CROP=${CROP:-auto}
HEIGHT=${HEIGHT:-720}

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)"; exit 1; }

if [[ $KEY == auto ]]; then
    KEY=0x$(ffmpeg -nostdin -v error -i "$IN" -frames:v 1 -vf "crop=8:8:4:4,scale=1:1:flags=area" -f rawvideo -pix_fmt rgb24 - | xxd -p | head -c 6)
    echo "Key colour: $KEY"
fi
KEYER="chromakey=color=$KEY:similarity=$SIMILARITY:blend=$BLEND"

if [[ $CROP == auto ]]; then
    # Union of the figure's bounding box over every frame, measured at quarter size.
    IFS=, read -r W H < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$IN")
    SW=$(( W / 4 / 2 * 2 )); SH=$(( H / 4 / 2 * 2 ))
    CROP=$(ffmpeg -nostdin -v error -i "$IN" -vf "scale=$SW:$SH,$KEYER,format=yuva420p,alphaextract,format=gray" -f rawvideo - |
        python3 "$(dirname "$0")/bbox.py" "$W" "$H" "$SW" "$SH")
    echo "Crop: $CROP"
fi
[[ $CROP == none ]] && CROP_FILTER="" || CROP_FILTER="crop=$CROP,"

ffmpeg -nostdin -v error -stats -y -i "$IN" -an \
    -vf "$CROP_FILTER$KEYER,despill=type=green,scale=-2:$HEIGHT,format=bgra" \
    -c:v hevc_videotoolbox -alpha_quality 0.75 -b:v 6M -tag:v hvc1 "$OUT"
echo "Wrote $OUT"
