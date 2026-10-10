#!/usr/bin/env python3
"""Align person frames (ground line + torso anchor), encode ProRes 4444 .mov files and contact sheets.

Usage:
    align_encode.py --dir work
Discovers sets from work/person/<set>_cell<N>_person.png (N = 1..4).
Frame order 1-2-3-4-3-2 ping-pong. fps by action suffix: wave=10, idle=6.
Writes work/frames/<set>/f%02d.png, work/mov/<set>_2x2.mov (yuva444p, real alpha)
and work/sheets/<set>.jpg (the six frames on a checkerboard).
"""
import argparse, os, subprocess
import numpy as np
from PIL import Image

FPS = {"wave": 10, "idle": 6}
ORDER = [0, 1, 2, 3, 2, 1]
PAD = 256


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def opaque(a):
    return a[:, :, 3] > 10


def ground(a):
    rows = np.where(opaque(a).any(axis=1))[0]
    return rows[-1]


def anchor(a):
    """Horizontal centre of the torso: the 35-55% band of the figure's own height."""
    m = opaque(a)
    rows = np.where(m.any(axis=1))[0]
    top, bottom = rows[0], rows[-1]
    h = bottom - top + 1
    band = m[top + int(h * 0.35):top + max(int(h * 0.55), int(h * 0.35) + 1)]
    if not band.any():
        band = m
    # Centroid rather than extent midpoint, so a moving arm or leg barely pulls it.
    return float(np.nonzero(band)[1].mean())


def shift(a, dy, dx):
    """Translate with transparent fill (no wrap-around)."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def checker(size, cell=16):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    tile = (((yy // cell) + (xx // cell)) % 2).astype(np.uint8)
    rgb = np.where(tile[..., None] == 1, 236, 255).astype(np.uint8).repeat(3, axis=2)
    return Image.fromarray(rgb)


def sheet(frames, path):
    w, h = frames[0].size
    pad = 8
    out = Image.new("RGB", (len(frames) * (w + pad) + pad, h + 2 * pad), (255, 255, 255))
    for k, f in enumerate(frames):
        bg = checker((w, h))
        bg.paste(f, (0, 0), f)
        out.paste(bg, (pad + k * (w + pad), pad))
    out.save(path, quality=88)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="work dir containing person/")
    args = ap.parse_args()
    person_d = os.path.join(args.dir, "person")
    fr_d = os.path.join(args.dir, "frames")
    mov_d = os.path.join(args.dir, "mov")
    sheet_d = os.path.join(args.dir, "sheets")
    for d in (fr_d, mov_d, sheet_d):
        os.makedirs(d, exist_ok=True)

    sets = set()
    for p in os.listdir(person_d):
        if p.endswith("_person.png"):
            stem = p[:-len("_person.png")]          # <set>_cell<N>
            sets.add(stem.rsplit("_cell", 1)[0])
    if not sets:
        raise SystemExit("no person layers found")

    skipped = 0
    for name in sorted(sets):
        action = name.rsplit("_", 1)[-1]
        fps = FPS.get(action, 10)
        paths = [os.path.join(person_d, f"{name}_cell{i}_person.png") for i in range(1, 5)]
        missing = [os.path.basename(p) for p in paths if not os.path.exists(p)]
        if missing:
            print(f"{name}: SKIPPED, missing {', '.join(missing)} (rerun slice_layer.py)", flush=True)
            skipped += 1
            continue
        # Pad so a shift never pushes the figure off the canvas.
        ims = [np.pad(load(p), ((PAD, PAD), (PAD, PAD), (0, 0))) for p in paths]
        empty = [i + 1 for i, im in enumerate(ims) if not opaque(im).any()]
        if empty:
            print(f"{name}: SKIPPED, cell {empty} has no opaque pixels (redo its Layer split)", flush=True)
            skipped += 1
            continue
        g0, a0 = ground(ims[0]), anchor(ims[0])
        shifted = [ims[0]] + [shift(im, int(round(g0 - ground(im))), int(round(a0 - anchor(im))))
                              for im in ims[1:]]
        mask = np.zeros(shifted[0].shape[:2], bool)
        for im in shifted:
            mask |= opaque(im)
        ys, xs = np.where(mask)
        x0, x1 = xs.min() // 2 * 2, min((xs.max() + 2) // 2 * 2, mask.shape[1])
        y0, y1 = ys.min() // 2 * 2, min((ys.max() + 2) // 2 * 2, mask.shape[0])
        crops = [Image.fromarray(im[y0:y1, x0:x1]) for im in shifted]
        w, h = crops[0].size
        if h > 960:
            nw = max(2, int(w * 960 / h) // 2 * 2)
            crops = [c.resize((nw, 960), Image.LANCZOS) for c in crops]
            w, h = crops[0].size
        fdir = os.path.join(fr_d, name)
        os.makedirs(fdir, exist_ok=True)
        frames = [crops[i] for i in ORDER]
        for k, f in enumerate(frames):
            f.save(os.path.join(fdir, f"f{k:02d}.png"))
        sheet(frames, os.path.join(sheet_d, f"{name}.jpg"))
        out = os.path.join(mov_d, f"{name}_2x2.mov")
        subprocess.run(["ffmpeg", "-y", "-framerate", str(fps), "-i",
                        os.path.join(fdir, "f%02d.png"),
                        "-c:v", "prores_ks", "-profile:v", "4444",
                        "-pix_fmt", "yuva444p10le", "-alpha_bits", "16",
                        "-vendor", "apl0", out],
                       check=True, capture_output=True)
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-show_entries", "stream=pix_fmt,width,height,duration",
             "-of", "default=noprint_wrappers=1", out],
            capture_output=True, text=True).stdout.strip().replace("\n", " ")
        print(f"{name}: {w}x{h} @ {fps}fps -> {probe}", flush=True)
    print(f"SKIPPED {skipped} set(s)" if skipped else "ALL ENCODED")
    return 1 if skipped else 0


if __name__ == "__main__":
    raise SystemExit(main())
