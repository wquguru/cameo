#!/bin/sh
# Creates the Python environment the scripts use and fetches the matting model (~1 GB, once).
# Prints the python to use. Safe to rerun.
set -e
ENV="${CAMEO_PKG_ENV:-$HOME/.cache/cameo-video-package/venv}"
command -v ffmpeg >/dev/null || { echo "MISSING: ffmpeg (brew install ffmpeg)"; exit 1; }
if [ ! -x "$ENV/bin/python" ]; then
  python3 -m venv "$ENV"
  "$ENV/bin/pip" install -q --upgrade pip
  "$ENV/bin/pip" install -q "rembg[cpu]" scipy numpy pillow
fi
# rembg's own download of the 1 GB model can stall; fetch it resumably and check its md5.
MODEL="$HOME/.u2net/birefnet-portrait.onnx"
URL=https://github.com/danielgatis/rembg/releases/download/v0.0.0/BiRefNet-portrait-epoch_150.onnx
MD5=c3a64a6abf20250d090cd055f12a3b67
mkdir -p "$HOME/.u2net"
if [ "$(md5 -q "$MODEL" 2>/dev/null)" != "$MD5" ]; then
  for i in 1 2 3 4 5 6; do curl -sSL -C - --retry 3 -o "$MODEL" "$URL" && break; sleep 2; done
  [ "$(md5 -q "$MODEL")" = "$MD5" ] || { echo "FAIL: model checksum mismatch, delete $MODEL and rerun"; exit 1; }
fi
echo "$ENV/bin/python"
