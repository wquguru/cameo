#!/usr/bin/env python3
"""Slice 2x2 grids into cells and split each cell into person/background via Design-Layer.

Usage:
    slice_layer.py --dir work
Expects work/grids/<name>_<action>_2x2.png; writes work/cells/ and work/person/.
Person layer = candidate with highest opaque-pixel fraction below 0.9.
Retries each cell up to 3 times on transient errors. Safe to re-run (skips done cells).
"""
import argparse, json, os, urllib.error, io, base64, time, urllib.request
from PIL import Image
import numpy as np

API = "https://openrouter.ai/api/v1/images"
LAYER_PROMPT = ("Split this image into exactly 2 layers: 1. the person, 2. the background. "
                "Keep the original canvas size and the exact pixel position of everything. "
                "Do not move, resize or redraw the person.")


def describe(e):
    """The API's own error message (e.g. a spending limit), not just the HTTP status."""
    if isinstance(e, urllib.error.HTTPError):
        try:
            return f"HTTP {e.code}: {json.loads(e.read())['error']['message']}"
        except Exception:
            pass
    return str(e)


def layer_call(cell_b64, key):
    body = json.dumps({"model": "inclusionai/ming-image-0.1-design-layer",
        "prompt": LAYER_PROMPT,
        "input_references": [{"type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{cell_b64}"}}]}).encode()
    req = urllib.request.Request(API, data=body, method="POST",
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {key}",
                 "HTTP-Referer": "https://localhost", "X-Title": "ming cameo"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def get_img(d):
    if d.get("b64_json"):
        return base64.b64decode(d["b64_json"])
    url = d.get("url", "")
    if url.startswith("data:"):
        return base64.b64decode(url.split(",", 1)[1])
    with urllib.request.urlopen(url, timeout=300) as r:
        return r.read()


def opaque_frac(png):
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return float((np.array(im)[:, :, 3] > 10).mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="work dir containing grids/")
    args = ap.parse_args()
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        raise SystemExit("OPENROUTER_API_KEY is not set; run check_openrouter.sh")
    grids = os.path.join(args.dir, "grids")
    cells_d = os.path.join(args.dir, "cells")
    person_d = os.path.join(args.dir, "person")
    os.makedirs(cells_d, exist_ok=True)
    os.makedirs(person_d, exist_ok=True)

    cells = []
    for g in sorted(os.listdir(grids)):
        if not g.endswith(".png"):
            continue
        name = g[:-4]
        if name.endswith("_2x2"):
            name = name[:-4]
        im = Image.open(os.path.join(grids, g))
        w, h = im.size
        if abs(w - h) > max(w, h) * 0.02:
            raise SystemExit(f"{g} is {w}x{h}, not a square 2x2 grid: regenerate it, never slice a bad grid")
        cw, ch = w // 2, h // 2
        for i, (x, y) in enumerate([(0, 0), (cw, 0), (0, ch), (cw, ch)], 1):
            p = os.path.join(cells_d, f"{name}_cell{i}.png")
            if not os.path.exists(p):
                im.crop((x, y, x + cw, y + ch)).save(p)
            cells.append((name, i, p))
    print(f"{len(cells)} cells", flush=True)

    log, fails = [], 0
    for name, i, p in cells:
        out = os.path.join(person_d, f"{name}_cell{i}_person.png")
        if os.path.exists(out):
            continue
        with open(p, "rb") as f:
            cb64 = base64.b64encode(f.read()).decode()
        t0 = time.time()
        for attempt in range(3):
            try:
                resp = layer_call(cb64, key)
                cands = []
                for d in resp.get("data", []):
                    png = get_img(d)
                    cands.append((opaque_frac(png), png))
                person = sorted([c for c in cands if c[0] < 0.9], key=lambda c: -c[0])
                if not person:
                    raise RuntimeError(f"no person candidate: {[round(c[0],3) for c in cands]}")
                frac, png = person[0]
                im = Image.open(io.BytesIO(png)).convert("RGBA")
                if im.size != (1024, 1024):
                    print(f"[{name}_cell{i}] canvas {im.size} -> resize to 1024", flush=True)
                    im = im.resize((1024, 1024), Image.LANCZOS)
                im.save(out)
                msg = f"[{name}_cell{i}] frac={frac:.3f} in {time.time()-t0:.0f}s"
                print(msg, flush=True); log.append(msg)
                break
            except Exception as e:
                print(f"[{name}_cell{i}] attempt {attempt+1} failed: {describe(e)}", flush=True)
                time.sleep(8)
        else:
            log.append(f"[{name}_cell{i}] FAILED"); fails += 1

    open(os.path.join(args.dir, "layer_log.txt"), "w").write("\n".join(log))
    print(f"DONE. failures: {fails}")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
