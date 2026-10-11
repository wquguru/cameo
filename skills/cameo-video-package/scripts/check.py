"""Check a character package and make one small contact sheet of its clips.

    check.py <package-dir> [preview.jpg]
Checks the manifest against the spec (every pose reachable, idle and walk present, files exist),
runs verify.swift on every clip (alpha, transparent background) and stacks every clip's frames
into preview.jpg on a checkerboard. Exits non-zero on failure.
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
    for need in ("idle", "walk"):
        if need not in kinds:
            errors.append(f"no {need} clip")
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
    print("FAIL: " + "; ".join(errors) if errors else "OK")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main(*sys.argv[1:3])
