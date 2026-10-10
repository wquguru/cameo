#!/usr/bin/env python3
"""Reads raw 8-bit alpha frames (sw x sh) on stdin and prints an ffmpeg crop W:H:X:Y in source
pixels (W x H): the figure's bounding box over every frame, padded on the top and sides.
Usage: ... | bbox.py W H sw sh"""
import sys
W, H, sw, sh = map(int, sys.argv[1:])
data = sys.stdin.buffer.read()
x0, y0, x1, y1 = sw, sh, -1, -1
for f in range(len(data) // (sw * sh)):
    frame = data[f * sw * sh:(f + 1) * sw * sh]
    for y in range(sh):
        row = frame[y * sw:(y + 1) * sw].translate(bytes(129) + b"\x01" * 127)
        left = row.find(1)
        if left >= 0:
            x0, x1, y0, y1 = min(x0, left), max(x1, row.rfind(1)), min(y0, y), max(y1, y)
if x1 < 0:
    sys.exit("no figure found; check KEY / SIMILARITY")
sx, sy = W / sw, H / sh
x0, x1, y0, y1 = x0 * sx, (x1 + 1) * sx, y0 * sy, (y1 + 1) * sy
pad = 0.05 * (y1 - y0)                      # margin on the top and sides, none below the feet
x0, x1, y0 = max(0, x0 - pad), min(W, x1 + pad), max(0, y0 - pad)
w, h = int(x1 - x0) // 2 * 2, int(min(H, y1) - y0) // 2 * 2
print(f"{w}:{h}:{int(x0)}:{int(y0)}")
