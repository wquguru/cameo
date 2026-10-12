#!/bin/sh
# Optional: MatAnyone 2 video matting (cut_clips.py --model matanyone2). Sharper edges than Vision and
# memory across frames; ~0.5 s a frame on Apple silicon (MPS). Needs uv (Python 3.10+) and ~1.3 GB.
# Prints the environment's folder. Safe to rerun.
set -e
BASE="${CAMEO_MA2_HOME:-$HOME/.cache/cameo-video-package}"
REPO="$BASE/matanyone2"
ENV="$BASE/ma2-venv"
COMMIT=0079197acd6d16a741f71558809c06c586c579e0
command -v uv >/dev/null || { echo "MISSING: uv (brew install uv)"; exit 1; }
if [ ! -d "$REPO/.git" ]; then
  git clone -q https://github.com/pq-yang/MatAnyone2 "$REPO"
fi
git -C "$REPO" fetch -q --depth 1 origin "$COMMIT" 2>/dev/null || true
git -C "$REPO" checkout -q "$COMMIT"
if [ ! -x "$ENV/bin/python" ]; then
  uv venv -q --python 3.11 "$ENV"
  # Only what inference needs: the package's own list adds gradio and Qt for its demo.
  VIRTUAL_ENV="$ENV" uv pip install -q torch torchvision opencv-python numpy pillow "imageio==2.25.0" \
    "imageio[ffmpeg]" av "huggingface_hub==0.36.2" safetensors tqdm hydra-core omegaconf einops kornia \
    easydict scipy typer requests
fi
# The script's own download can stall; fetch resumably and check the size.
W="$REPO/pretrained_models/matanyone2.pth"
URL=https://github.com/pq-yang/MatAnyone2/releases/download/v1.0.0/matanyone2.pth
SIZE=141429115
mkdir -p "$(dirname "$W")"
if [ "$(stat -f %z "$W" 2>/dev/null)" != "$SIZE" ]; then
  for i in 1 2 3 4 5 6; do curl -sSL -C - --retry 3 -o "$W" "$URL" && break; sleep 2; done
  [ "$(stat -f %z "$W")" = "$SIZE" ] || { echo "FAIL: weights incomplete, delete $W and rerun"; exit 1; }
fi
echo "$BASE"
