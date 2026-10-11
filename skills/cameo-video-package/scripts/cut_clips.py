"""Cut chain videos (see chains.py) into package clips.

    cut_clips.py <videos-dir> <package-dir> <Name>          # one character: builds a new package
    cut_clips.py <videos-dir> <duo-package-dir> X --duo     # duo: adds the cut actions to an existing duo package
    --force     cut even when the first frames don't look like a chain start (see preflight)
    --model M   rembg model (default birefnet-portrait: cleanest edges, ~10 s/frame;
                isnet-general-use ~1 s/frame; isnet-anime for flat anime art)
Expects <chain>.mp4 files named after chains.py keys (walk.mp4, lie.mp4, ...); missing chains are skipped.
The camera is static, so one scale/offset (from the first frame) is used for the whole
video: motion such as jumps and lying down stays where the model put it.
"""
import json, subprocess, sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C
from chains import CHAINS, OPTIONAL, DUO_CHAINS

FPS = 12
MODEL = "birefnet-portrait"
FORCE = False


def read_video(path):
    w, h = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                    "stream=width,height", "-of", "csv=p=0", str(path)],
                                   capture_output=True, text=True, check=True).stdout.strip().split(","))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"fps={FPS}", "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    arr = np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3)
    return [Image.fromarray(a) for a in arr]


def preflight(path, duo=False):
    """Seconds-long look at the first frame before the slow cut: the cutter relies on every chain
    starting with the full figure standing on a flat background. Returns problems (empty = fine)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-frames:v", "1", "-f", "image2pipe",
                          "-vcodec", "png", "-"], capture_output=True, check=True).stdout
    import io
    first = Image.open(io.BytesIO(raw)).convert("RGB")
    fig = C.cutout(first, MODEL, soft=True)
    x0, y0, x1, y1 = C.bbox(fig)
    w, h = first.size
    problems = []
    if y0 <= 2 or y1 >= h - 2:
        problems.append("the figure touches the top or bottom of the frame (close-up?): the whole body, "
                        "with room above the head, must stay in frame")
    if not duo and (y1 - y0) < 1.5 * (x1 - x0):
        problems.append("the first frame is not a standing figure (sitting, lying or crouching?): every chain "
                        "must start standing still, facing the viewer")
    if C.key_color(first) is None:
        problems.append("note: the background is not a flat chroma colour, so edges get no colour clean-up "
                        "(use the start.png from prompts.py)")
    return problems


class Video:
    """Cut-out, canvas-placed frames of one chain video plus the measures used to find cuts."""

    def __init__(self, path, duo=False):
        cache = Path(path).with_suffix(f".{MODEL}.cut")   # rembg is the slow part: keep its output between runs
        if cache.is_dir() and cache.stat().st_mtime >= Path(path).stat().st_mtime:
            cut = [Image.open(p).convert("RGBA") for p in sorted(cache.glob("*.png"))]
        else:
            raw = read_video(path)
            key = C.key_color(raw[0])
            cut = [C.cutout(f, MODEL, soft=True) for f in raw]
            if key is not None:   # flat chroma background: clean edges and leftover patches against it
                cut = [C.dekey(c, f, key) for c, f in zip(cut, raw)]
            cache.mkdir(exist_ok=True)
            for k, c in enumerate(cut):
                c.save(cache / f"{k:04d}.png")
        ref = cut[0]
        x0, y0, x1, y1 = C.bbox(ref)
        ax = (x0 + x1) / 2 if duo else C.anchor_x(ref)
        # Scale from the standing height, not the first frame: a video may start sitting or crouched.
        # The camera is static, so the floor is the lowest the feet get.
        boxes = [C.bbox(c) for c in cut]
        heights = [(b[3] - b[1]) if duo else C.body_height(c) for b, c in zip(boxes, cut)]
        hgt = float(np.percentile(heights, 95))
        ground = int(np.percentile([b[3] for b in boxes], 95))
        self.notes = []
        if heights[0] < 0.85 * hgt:
            self.notes.append("first frame is not standing (sitting/crouching start image?): front clips "
                              "start and end on that pose; regenerate from a standing start image for clean seams")
        self.cut, self.k, self.ax, self.ground = cut, C.FIG_H / hgt, ax, ground
        # Half the canvas width this video needs around the anchor (lying figures are long).
        self.half = max(max(ax - b[0], b[2] - ax) for b in boxes) * self.k

    def place(self):
        """Put every frame on the package canvas (C.W, chosen once for all videos) and measure it."""
        self.frames = [C.place(c, C.W, C.H, self.k, ax=self.ax, ground=self.ground) for c in self.cut]
        small = [np.asarray(f.resize((C.W // 8, C.H // 8), Image.BILINEAR), np.float32) / 255 for f in self.frames]
        # Premultiplied so the background colour of transparent pixels doesn't count.
        self.feat = np.stack([np.concatenate([s[..., :3] * s[..., 3:], s[..., 3:]], -1).ravel() for s in small])
        self.n = len(self.frames)
        d0 = self.dist(0)
        base = np.median(d0[1:max(2, FPS // 3)])
        thr = base * 2 + 0.15 * (np.percentile(d0, 90) - base)
        self.rest = clean(d0 < thr, FPS // 4)

    def dist(self, i, j=None):
        if j is None:
            return np.abs(self.feat - self.feat[i]).mean(axis=1)
        return float(np.abs(self.feat[i] - self.feat[j]).mean())

    def best_loop(self, a, b, lo, hi):
        """(i, j) in [a, b] with lo <= j-i <= hi seconds whose frames match best (j excluded from the loop)."""
        best = None
        for i in range(a, b):
            for j in range(i + int(lo * FPS), min(b, i + int(hi * FPS)) + 1):
                # Prefer loops from the middle of the stretch: the edges are still settling.
                d = self.dist(i, j) * (1 + 0.3 * abs((i + j) / 2 - (a + b) / 2) / max(1, b - a))
                if best is None or d < best[0]:
                    best = (d, i, j)
        return best[1:] if best else None


def enter_exit(v, a, b, i, j):
    """Shortest way into and out of the loop i..j-1: the loop is cyclic, so enter it at whichever
    phase best matches an early frame of the stretch, and leave at the first late frame that
    matches that phase again. Returns (entry frame, loop frames rotated to start there, exit frame)."""
    p = j - i
    t, m = min(((t, m) for t in range(a, min(a + p, j)) for m in range(p)), key=lambda tm: v.dist(tm[0], i + tm[1]))
    loop = v.frames[i + m:j] + v.frames[i:i + m]
    e = min(range(max(t + 1, b - p), b + 1), key=lambda e: v.dist(e, i + m))
    return t, loop, e


def clean(mask, min_run):
    """Flip runs shorter than min_run (flicker) to match their neighbours."""
    m = list(mask)
    for val in (False, True):
        i = 0
        while i < len(m):
            j = i
            while j < len(m) and m[j] == m[i]:
                j += 1
            if m[i] == val and j - i < min_run and i > 0 and j < len(m):
                m[i:j] = [not val] * (j - i)
            i = j
    return np.array(m)


def runs(mask):
    out, i = [], 0
    while i < len(mask):
        if mask[i]:
            j = i
            while j < len(mask) and mask[j]:
                j += 1
            out.append((i, j - 1))
            i = j
        else:
            i += 1
    return out


def xfade(frames, ref, n=3, end=True):
    """Blend the last (or first) n frames toward `ref` so the clip lands exactly on the shared pose."""
    frames = list(frames)
    n = min(n, len(frames) - 1)
    for t in range(1, n + 1):
        i = len(frames) - 1 - n + t if end else n - t
        frames[i] = Image.blend(frames[i], ref, t / n)
    return frames


def clip(cid, kind, a, b, frames, **kw):
    loop = kind in ("idle", "walk")
    c = {"id": cid, "kind": kind, "from": a, "to": b, "loop": loop, "fps": FPS, "frames": frames}
    c.update(kw)
    return c


def side_stretch(v, measure, thr):
    """Longest run where measure(frame) < thr, with the rest frames that frame it."""
    m = clean(np.array([measure(f) < thr for f in v.frames]), FPS // 4)
    rs = runs(m)
    if not rs:
        return None
    a, b = max(rs, key=lambda r: r[1] - r[0])
    r0 = max([i for i in range(a) if v.rest[i]], default=0)
    r1 = min([i for i in range(b + 1, v.n) if v.rest[i]], default=v.n - 1)
    return r0, a, b, r1


def cut_walk(v, ref, cuts):
    st = side_stretch(v, C.symmetry, 0.8)
    if not st:
        raise SystemExit("walk: no profile frames found")
    r0, a, b, r1 = st
    pad = FPS // 4
    i, j = v.best_loop(a + pad, b - pad, 0.6, 1.6)
    t, walk, e = enter_exit(v, a, b, i, j)
    flip = sum(C.facing(f) == "left" for f in walk) > len(walk) / 2
    fl = (lambda fs: [f.transpose(Image.FLIP_LEFT_RIGHT) for f in fs]) if flip else (lambda fs: fs)
    spread = sorted(C.leg_spread(f) for f in walk)[-2:]
    step = sum(spread) / 2 - 0.11 * C.FIG_H
    speed = int(min(480, max(220, round(0.9 * 2 * step / (len(walk) / FPS)))))
    out = []
    if r0 >= FPS:   # enough standing at the start for a breathing idle
        li = v.best_loop(0, r0, 0.8, 3)
    if r0 >= FPS and li:
        idle = v.frames[li[0]:li[1]]
        out.append(clip("idle", "idle", "front", "front", idle + [idle[0]]))
    else:
        out.append(clip("idle", "idle", "front", "front", C.breathe(ref)))
    out.append(clip("turn_to_side", "transition", "front", "side", fl(v.frames[r0:t] + [walk[0]])))
    out.append(clip("walk", "walk", "side", "side", fl(walk + [walk[0]]), speed=speed))
    out.append(clip("turn_to_front", "transition", "side", "front", xfade(fl([walk[0]] + v.frames[e + 1:r1 + 1]), ref)))
    return out, f"walk: idle {len(out[0]['frames'])}f, turn {r0}-{t}, loop {i}-{j}, turn {e}-{r1}, speed {speed}"


def lying_height(f):
    """Below 1 when the figure lies: well under standing height and long rather than tall
    (sitting is short too, but taller than wide)."""
    x0, y0, x1, y1 = C.bbox(f)
    return max((y1 - y0) / C.FIG_H / 0.75, (y1 - y0) / max(1, x1 - x0) / 1.1)


def cut_lie(v, ref, cuts):
    st = side_stretch(v, lying_height, 1.0)
    if not st:
        raise SystemExit("lie: no lying frames found")
    r0, a, b, r1 = st
    pad = FPS // 3
    loop = v.best_loop(a + pad, b - pad, 0.8, 2.5)
    if loop:
        i, j = loop
        t, lie, e = enter_exit(v, a, b, i, j)
        how = f"loop {i}-{j}"
    else:   # too little lying for a loop: play the lying stretch forward and back
        t, e = a + pad // 2, max(a + pad // 2 + 1, b - pad // 2)
        lie = v.frames[t:e + 1] + v.frames[t + 1:e][::-1]
        how = f"ping-pong {t}-{e} (short lying stretch {b - a + 1}f)"
    out = [clip("lie_down", "transition", "front", "lie", v.frames[r0:t] + [lie[0]]),
           clip("lie_idle", "action", "lie", "lie", lie + [lie[0]], repeat=3),
           clip("get_up", "transition", "lie", "front", xfade([lie[0]] + v.frames[e + 1:r1 + 1], ref))]
    return out, f"lie: down {r0}-{t}, {how}, up {e}-{r1}"


def cut_lie_mid(v, ref, cuts, lie_ref=None):
    st = side_stretch(v, lying_height, 1.0)
    if not st:
        raise SystemExit("lie_mid: no lying frames found")
    r0, a, b, r1 = st
    pad = FPS // 3
    fr = v.frames[a + pad:b - pad + 1]
    if lie_ref is not None:   # start and end on the lie_idle pose so it joins the lying loop
        fr = xfade(xfade(fr, lie_ref, end=False), lie_ref)
    return [clip(cuts[0], "action", "lie", "lie", fr)], f"{cuts[0]}: {a + pad}-{b - pad}"


def cut_actions(v, ref, cuts):
    rs = runs(~v.rest)
    while len(rs) > len(cuts):   # one action that paused midway: merge the closest pair
        gaps = [b[0] - a[1] for a, b in zip(rs, rs[1:])]
        k = gaps.index(min(gaps))
        rs[k:k + 2] = [(rs[k][0], rs[k + 1][1])]
    out = []
    for cid, (a, b) in zip(cuts, rs):
        a, b = max(0, a - 2), min(v.n - 1, b + 2)
        out.append(clip(cid, "action", "front", "front", xfade(xfade(v.frames[a:b + 1], ref, end=False), ref)))
    note = f"actions: {len(rs)} found for {len(cuts)}" + ("" if len(rs) == len(cuts) else "  <-- CHECK")
    return out, note + " " + ", ".join(f"{c}={a}-{b}" for c, (a, b) in zip(cuts, rs))


def main(src, out, name, duo=False):
    src, out = Path(src), Path(out)
    specs = DUO_CHAINS if duo else {**CHAINS, **OPTIONAL}
    if duo:
        C.W = 1024
    clips, report, ref, lie_ref = [], [], None, None
    if duo:   # anchor every cut on the existing package's idle pose
        m = json.load(open(out / "manifest.json"))
        idle = next(c for c in m["clips"] if c["kind"] == "idle")
        ref = C.load_clip(out / idle["file"], m["width"], m["height"])[0]
    order = sorted(specs, key=lambda k: {"walk": 0, "lie": 1}.get(k, 2))   # ref and lie_ref come first
    found = [cid for cid in order if (src / f"{cid}.mp4").exists()]
    if not found:
        raise SystemExit(f"no chain videos in {src} (expected {', '.join(k + '.mp4' for k in order)})")
    blocking = []
    for cid in found:
        for msg in preflight(src / f"{cid}.mp4", duo):
            print(f"{cid}.mp4: {msg}")
            if not msg.startswith("note:"):
                blocking.append(cid)
    if blocking and not FORCE:
        raise SystemExit("Stopped before the slow cut. Regenerate those videos from prompts.py's start.png "
                         "and prompt, or rerun with --force to cut anyway (expect a wrong scale and bad seams).")
    videos = {cid: Video(src / f"{cid}.mp4", duo) for cid in found}
    if not duo:   # one canvas for the whole package, wide enough for the widest pose (lying)
        C.W = max(C.W, int(np.ceil((2 * max(v.half for v in videos.values()) + 16) / 32) * 32))
    for v in videos.values():
        v.place()
    for cid, v in videos.items():
        spec = specs[cid]
        if ref is None:
            ref = v.frames[0]
        if spec["mode"] == "walk":
            cs, note = cut_walk(v, ref, spec["cuts"])
            ref = cs[0]["frames"][0]   # the idle pose is the seam every front clip lands on
        elif spec["mode"] == "lie":
            cs, note = cut_lie(v, ref, spec["cuts"])
            lie_ref = cs[1]["frames"][0]
        elif spec["mode"] == "lie_mid":
            cs, note = cut_lie_mid(v, ref, spec["cuts"], lie_ref)
        else:
            cs, note = cut_actions(v, ref, spec["cuts"])
        clips += cs
        report.append(f"{cid}.mp4 ({v.n}f): {note}")
        report += [f"  <-- CHECK {cid}: {n}" for n in v.notes]
    if not duo and not any(c["kind"] == "idle" for c in clips):
        # No walk video: idle comes from the standing (or sitting) start of the first video.
        v = next(iter(videos.values()))
        r = runs(v.rest)[0] if runs(v.rest) else (0, 0)
        loop = v.best_loop(r[0], r[1], 0.8, 3) if r[1] - r[0] >= FPS else None
        idle = v.frames[loop[0]:loop[1]] + [v.frames[loop[0]]] if loop else C.breathe(ref)
        clips.insert(0, clip("idle", "idle", "front", "front", idle))
        report.append("  no walk.mp4: the character stays in place (idle from the start of the first video)")
    for c in clips:   # lying figures are wide: say so when the canvas cuts them off
        hit = sum(np.asarray(f)[:, [0, -1], 3].max() > 24 for f in c["frames"])
        if hit:
            report.append(f"  <-- CHECK {c['id']}: {hit}/{len(c['frames'])} frames touch the canvas side (clipped)")
    print("\n".join(report))
    if duo:
        m = json.load(open(out / "manifest.json"))
        new = {c["id"] for c in clips}
        m["clips"] = [c for c in m["clips"] if c["id"] not in new]
        for c in clips:
            frames = c.pop("frames")
            c["file"] = f"clips/{c['id']}.mov"
            C.encode(frames, str(out / c["file"]), c["fps"])
            C.sheet(frames, str(out / f"sheet_{c['id']}.jpg"), cell_h=192, cols=12)
            m["clips"].append(c)
        json.dump(m, open(out / "manifest.json", "w"), indent=1)
        return
    poster = clips[0]["frames"][0]
    C.write_package(out, name, clips, width=C.W)
    poster.save(out / "poster.png")


if __name__ == "__main__":
    if "--model" in sys.argv:
        MODEL = sys.argv[sys.argv.index("--model") + 1]
    FORCE = "--force" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--") and a != MODEL]
    main(*args[:3], duo="--duo" in sys.argv)
