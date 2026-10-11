"""Check a character package and make one small contact sheet of its clips.

    check.py <package-dir> [preview.jpg]
Checks the manifest against the spec (every pose reachable, idle and walk present, files exist),
runs verify.swift on every clip (alpha, transparent background) and stacks every clip's frames
into preview.jpg on a checkerboard (small: for the structure, not the edges). Next to it,
preview-edges.png holds six random frames at full size on dark and on light grey, lossless, for
judging edges (halos, fringes, leftover key); a few frames show edge problems as well as all would. Exits non-zero on failure.
"""
import json, subprocess, sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import common as C


def main(pkg, preview=None):
    pkg = Path(pkg)
    m = json.load(open(pkg / "manifest.json"))
    clips = m["clips"]
    errors = []
    kinds = {c["kind"] for c in clips}
    if "idle" not in kinds:
        errors.append("no idle clip")
    if "walk" not in kinds:
        print("note: no walk clip, the character stays in place")
    poses = {p for c in clips for p in (c.get("from", "front"), c.get("to", "front"))}
    trans = [(c.get("from", "front"), c.get("to", "front")) for c in clips if c["kind"] == "transition"]
    reach, frontier = {"front"}, ["front"]
    while frontier:
        p = frontier.pop()
        for a, b in trans:
            if a == p and b not in reach:
                reach.add(b)
                frontier.append(b)
    if poses - reach:
        errors.append(f"poses not reachable from front: {sorted(poses - reach)}")
    for c in clips:
        f = pkg / c["file"]
        if not f.exists():
            errors.append(f"missing {c['file']}")
            continue
        r = subprocess.run(["swift", str(HERE / "verify.swift"), str(f)], capture_output=True, text=True)
        line = (r.stdout.strip().splitlines() or ["?"])[-1]
        print(f"{c['id']:14} {c['kind']:10} {c.get('from', 'front')}→{c.get('to', 'front'):6} {line}")
        if r.returncode:
            errors.append(f"{c['id']}: {line}")
    if preview:
        rows = []
        for c in clips:
            fr = C.load_clip(pkg / c["file"], m["width"], m["height"])
            step = max(1, len(fr) // 12)
            cells = [C.checker(f.resize((m["width"] * 120 // m["height"], 120))) for f in fr[::step][:12]]
            row = Image.new("RGB", (sum(x.width for x in cells), 120), "white")
            x = 0
            for cell in cells:
                row.paste(cell, (x, 0))
                x += cell.width
            rows.append(row)
        sheet = Image.new("RGB", (max(r.width for r in rows), 120 * len(rows)), "white")
        for i, r in enumerate(rows):
            sheet.paste(r, (0, 120 * i))
        sheet.save(preview, quality=80)
        print(f"preview: {preview} (rows: {', '.join(c['id'] for c in clips)})")
        edges = Path(preview).with_name(Path(preview).stem + "-edges.png")
        edge_sheet(pkg, m, clips, edges)
        print(f"edges: {edges} (six random frames at full size, on dark and on light)")
    print("FAIL: " + "; ".join(errors) if errors else "OK")
    sys.exit(1 if errors else 0)


def edge_sheet(pkg, m, clips, out, n=6, width=2400):
    """n random frames (from different clips where possible), cropped to the figure, on dark and on
    light grey, labelled with clip and frame."""
    import random
    from PIL import ImageDraw
    rnd = random.Random()
    tiles = []
    for c in rnd.sample(clips, min(n, len(clips))):
        fr = C.load_clip(pkg / c["file"], m["width"], m["height"])
        i = rnd.randrange(len(fr))
        f = fr[i]
        x0, y0, x1, y1 = C.bbox(f)
        f = f.crop((max(0, x0 - 12), max(0, y0 - 12), min(f.width, x1 + 12), min(f.height, y1 + 12)))
        tile = Image.new("RGB", (2 * f.width + 8, f.height + 22), (90, 90, 90))
        for k, bg in enumerate([(40, 40, 40), (235, 235, 235)]):
            under = Image.new("RGBA", f.size, bg + (255,))
            under.alpha_composite(f)
            tile.paste(under.convert("RGB"), (k * (f.width + 8), 22))
        ImageDraw.Draw(tile).text((4, 5), f"{c['id']} #{i}", fill="white")
        tiles.append(tile)
    rows, row = [], []
    for t in tiles:   # pack left to right
        if row and sum(x.width + 8 for x in row) + t.width > width:
            rows.append(row)
            row = []
        row.append(t)
    rows.append(row)
    sheet = Image.new("RGB", (max(sum(x.width + 8 for x in r) for r in rows), sum(max(x.height for x in r) + 8 for r in rows)),
                      (90, 90, 90))
    y = 0
    for r in rows:
        x = 0
        for t in r:
            sheet.paste(t, (x, y))
            x += t.width + 8
        y += max(t.height for t in r) + 8
    sheet.save(out)


if __name__ == "__main__":
    main(*sys.argv[1:3])
