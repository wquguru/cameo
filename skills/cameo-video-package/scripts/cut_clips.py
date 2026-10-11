"""Cut chain videos (see chains.py) into package clips.

    cut_clips.py <videos-dir> <package-dir> <Name>          # one character: builds a new package
    cut_clips.py <videos-dir> <duo-package-dir> X --duo     # duo: adds the cut actions to an existing duo package
    --force     cut even when the first frames don't look like a chain start (see preflight)
    --model M   matting model (default birefnet-portrait: cleanest edges, ~10 s/frame; vision: macOS's
                own, ~0.2 s/frame; isnet-general-use ~1 s/frame; isnet-anime for flat anime art)
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


def grab(path, t=None, from_end=False):
    """One frame as RGB: at t seconds, or the last one."""
    import io
    pos = ["-sseof", "-0.2"] if from_end else (["-ss", str(t)] if t else [])
    raw = subprocess.run(["ffmpeg", "-v", "error", *pos, "-i", str(path), "-frames:v", "1", "-f", "image2pipe",
                          "-vcodec", "png", "-"], capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(raw)).convert("RGB") if raw else None


def preflight(path, duo=False):
    """Seconds-long look before the slow cut: the cutter relies on every chain starting (or standing up
    first, chains.rise) and ending with the full figure standing on a flat background. Standing is
    judged against the video's own last frame, so a short or wide figure (chibi, animal) still counts.
    Returns problems (empty = fine)."""
    first = grab(path)
    fig = C.cutout(first, MODEL, soft=True)
    x0, y0, x1, y1 = C.bbox(fig)
    w, h = first.size
    problems = []
    if y0 <= 2 or y1 >= h - 2:
        problems.append("the figure touches the top or bottom of the frame (close-up?): the whole body, "
                        "with room above the head, must stay in frame")
    if not duo:
        stand = C.body_height(C.cutout(grab(path, from_end=True), MODEL, soft=True))
        if C.body_height(fig) < 0.85 * stand:
            # Not standing yet: look every half second up to 2.5 s and stop at the first stand.
            for t in (1, 1.5, 2, 2.5):
                f = grab(path, t)
                if f is not None and C.body_height(C.cutout(f, MODEL, soft=True)) >= 0.9 * stand:
                    problems.append(f"note: starts in another pose and stands by {t:g} s; the cut starts once it stands")
                    break
            else:
                problems.append("the figure doesn't stand at the start or by 2.5 s (compared with the last frame): "
                                "every chain must start standing, or stand up first (prompts.py writes such "
                                "prompts for any start image), and end standing")
    if C.key_color(first) is None:
        problems.append("note: the background is not a flat chroma colour, so edges get no colour clean-up "
                        "(use the start.png from prompts.py)")
    return problems


class Video:
    """Cut-out, canvas-placed frames of one chain video plus the measures used to find cuts."""

    def __init__(self, path, duo=False):
        # rembg is the slow part: keep its raw output between runs; the edge clean-up is redone each
        # time (seconds), so changes to it don't need the matting again.
        cache = Path(path).with_suffix(f".{MODEL}.matte")
        raw = read_video(path)
        if cache.is_dir() and cache.stat().st_mtime >= Path(path).stat().st_mtime:
            cut = [Image.open(p).convert("RGBA") for p in sorted(cache.glob("*.png"))]
        else:
            cut = C.cutout_many(raw, MODEL, soft=True)
            cache.mkdir(exist_ok=True)
            for k, c in enumerate(cut):
                c.save(cache / f"{k:04d}.png")
        key = C.key_color(raw[0])
        if key is not None:   # flat chroma background: clean edges and leftover patches against it
            cut = [C.dekey(c, f, key) for c, f in zip(cut, raw)]
        # Scale from the standing height, not the first frame: a video may start sitting or crouched.
        # The camera is static, so the floor is the lowest the feet get.
        boxes = [C.bbox(c) for c in cut]
        heights = [(b[3] - b[1]) if duo else C.body_height(c) for b, c in zip(boxes, cut)]
        # Standing height: every chain ends standing still, so its last frames are this figure's own
        # standing pose, whatever its build (a fixed height/width ratio fails chibis and animals). The top
        # percentile of all frames would count arms stretched overhead (hands together read as a head).
        end = float(np.median(heights[-max(2, FPS // 2):]))
        top = float(np.percentile(heights, 95))
        hgt = top if duo or end < 0.8 * top else end
        ground = int(np.percentile([b[3] for b in boxes], 95))
        self.notes, self.skipped, self.dx, self.cut0 = [], 0, 0, 0
        if not duo and end < 0.8 * top:
            self.notes.append("the video doesn't end standing: scale taken from its tallest frames")
        if heights[0] < 0.85 * hgt:
            # A start image that isn't standing: the prompt (chains.rise) has the figure stand up first.
            # Cut from the first steady standing stretch, so frame 0 is the rest pose as usual; a frame
            # still rising would make every later frame look equally unlike it, and no action be found.
            hold = FPS // 3
            up = [h >= 0.97 * hgt for h in heights]
            k = next((i for i in range(min(len(cut), 4 * FPS)) if all(up[i:i + hold])), None)
            if k is None:
                self.notes.append("first frame is not standing and the figure doesn't stand up in the first 4 s: "
                                  "front clips start and end on that pose; regenerate with prompts.py's prompts")
            else:
                self.skipped, cut, boxes = k, cut[k:], boxes[k:]
        ref = cut[0]
        x0, y0, x1, y1 = C.bbox(ref)
        ax = (x0 + x1) / 2 if duo else C.anchor_x(ref)
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
        if self.skipped:
            # Just stood up: the first standing frames still sway. Rest on the stillest frame of the
            # next second, or every later frame looks about as unlike frame 0 and no action is found.
            r = min(range(min(FPS, self.n - 2)), key=lambda i: self.dist(i, i + 1) + self.dist(i, i + 2))
            self.frames, self.feat, self.n, self.skipped = self.frames[r:], self.feat[r:], self.n - r, self.skipped + r
            self.cut0 = r
        d0 = self.dist(0)
        base = np.median(d0[1:max(2, FPS // 3)])
        spread = np.percentile(d0, 90) - base
        # A still start makes base ~0 and the threshold tight, but a figure rarely lands back exactly
        # where it began (after a jump, a bow): allow a quarter of the video's motion at least.
        # (Not "or like the last frame": a wave moves one arm and looks like any standing frame.)
        thr = max(base * 2 + 0.15 * spread, 0.25 * spread)
        self.rest = clean(d0 < thr, FPS // 4)

    def align(self, ref, reach=24):
        """Shift the whole video sideways so its first (standing) frame lines up with `ref`, the shared
        standing pose every front clip blends into. Videos that start in another pose stand up in a
        slightly different spot each time, and the blend would show two figures. Sideways only: the
        feet stay on the ground."""
        ra = np.asarray(ref)[:, :, 3] > 128
        fa = np.asarray(self.frames[0])[:, :, 3] > 128
        dx = min(range(-reach, reach + 1), key=lambda d: np.logical_xor(ra, np.roll(fa, d, 1)).sum())
        if dx:
            def shift(f):
                im = Image.new("RGBA", f.size, (0, 0, 0, 0))
                im.alpha_composite(f, (dx, 0) if dx > 0 else (0, 0), (0, 0) if dx > 0 else (-dx, 0))
                return im
            self.frames = [shift(f) for f in self.frames]
        self.dx = dx

    def local(self, i, cell=4):
        """Per frame, the mean change of the most-changed cell x cell patch against frame i."""
        h, w = C.H // 8 // cell * cell, C.W // 8 // cell * cell
        f = self.feat.reshape(self.n, C.H // 8, C.W // 8, 4)[:, :h, :w]
        d = np.abs(f - f[i]).mean(-1).reshape(self.n, h // cell, cell, w // cell, cell).mean((2, 4))
        return d.reshape(self.n, -1).max(1)

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
    # Profile frames are lopsided, but how lopsided depends on the figure (a slim one in a loose shirt
    # stays around 0.8): measure against this figure's own standing symmetry.
    stand = float(np.median([C.symmetry(f) for f in v.frames[:FPS // 2]]))
    st = side_stretch(v, C.symmetry, min(0.88, max(0.8, stand - 0.06)))
    if not st:
        raise SystemExit("walk: no profile frames found")
    r0, a, b, r1 = st
    pad = FPS // 4
    # Lopsided is not enough: lying and crawling are lopsided too. Walking frames stand upright at
    # full height; anything else would slide a lying figure across the desktop.
    upright = [C.body_height(f) / C.FIG_H > 0.85 for f in v.frames[a:b + 1]]
    if sum(upright) < 0.8 * len(upright):
        raise SystemExit(f"walk: the side-view stretch ({a}-{b}) is not upright walking "
                         f"({sum(upright)}/{len(upright)} frames at standing height). Is this really walk.mp4?")
    loop = v.best_loop(a + pad, b - pad, 0.6, 1.6)
    if not loop:
        raise SystemExit(f"walk: side-view stretch {a}-{b} is too short for a stride loop: regenerate walk.mp4")
    i, j = loop
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
    """Find len(cuts) actions between standing rests. Measured by the most-changed patch rather than
    the whole frame (a wave moves one arm, a small share of the figure), and against the rest level
    of this video (start, end and the stillest point between actions), since a figure rarely lands
    back exactly where it stood; the known action count settles what is left."""
    s = v.local(0)
    s = np.array([np.median(s[max(0, i - 1):i + 2]) for i in range(v.n)])
    hi = np.percentile(s, 90)
    tail = float(np.median(s[-max(2, FPS // 3):]))
    edge = FPS // 2
    inner = s[edge:v.n - edge] if v.n > 2 * edge + 1 else s
    level = max(s[0], tail, float(inner.min()))
    mid = (level + hi) / 2
    rs = runs(s > mid)
    while len(rs) > len(cuts):   # one action that paused midway: merge the closest pair
        gaps = [b[0] - a[1] for a, b in zip(rs, rs[1:])]
        k = gaps.index(min(gaps))
        rs[k:k + 2] = [(rs[k][0], rs[k + 1][1])]
    while 0 < len(rs) < len(cuts):   # two actions with no clear rest between: split at the stillest point
        k = max(range(len(rs)), key=lambda i: rs[i][1] - rs[i][0])
        a, b = rs[k]
        if b - a < FPS:
            break
        m = min(range(a + FPS // 3, b - FPS // 3 + 1), key=lambda i: s[i])
        rs[k:k + 1] = [(a, m - 1), (m + 1, b)]
    # Widen each action while the figure is still heading back towards standing (a crouch before a
    # jump), and stop where that levels off: a pause between two actions may be in a slightly different
    # pose than the start, and must not be counted as part of either.
    eps = 0.02 * (hi - level)
    wide = []
    for k, (a, b) in enumerate(rs):
        lo_lim = wide[-1][1] + 1 if wide else 0
        hi_lim = rs[k + 1][0] - 1 if k + 1 < len(rs) else v.n - 1
        look = FPS // 4   # a slow settle has small plateaus: look a few frames ahead
        while a > lo_lim and s[max(lo_lim, a - look):a].min() < s[a] - eps:
            a -= 1
        while b < hi_lim and s[b + 1:min(hi_lim, b + look) + 1].min() < s[b] - eps:
            b += 1
        wide.append((a, b))
    out = []
    pad = FPS // 4
    for k, (cid, (a, b)) in enumerate(zip(cuts, wide)):
        # Keep a few still frames at each end, so the blend into the shared pose isn't over a moving arm,
        # but never past halfway to the neighbouring action.
        lo = (wide[k - 1][1] + a) // 2 + 1 if k else 0
        hi_ = (b + wide[k + 1][0]) // 2 if k + 1 < len(wide) else v.n - 1
        a, b = max(lo, a - pad), min(hi_, b + pad)
        out.append(clip(cid, "action", "front", "front", xfade(xfade(v.frames[a:b + 1], ref, end=False), ref)))
    note = f"actions: {len(wide)} found for {len(cuts)}" + ("" if len(wide) == len(cuts) else "  <-- CHECK")
    return out, note + " " + ", ".join(f"{c}={a}-{b}" for c, (a, b) in zip(cuts, wide))


def main(src, out, name, duo=False):
    src, out = Path(src), Path(out)
    specs = DUO_CHAINS if duo else {**CHAINS, **OPTIONAL}
    if duo:
        C.W = 1024
    clips, report, ref, lie_ref, stand_note = [], [], None, None, None
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
        elif not duo:
            v.align(ref)
        if spec["mode"] == "walk":
            cs, note = cut_walk(v, ref, spec["cuts"])
            if v.skipped:
                # The walk stood up from another pose: its standing frame, cut out at full size, is the
                # start image the other videos should share (prompts.py --pose stand, loop mode), so
                # every clip starts and ends on the same pose instead of ghosting at the seams.
                C.bleed(v.cut[v.cut0]).save(src / "stand.png")
                stand_note = (f"stand.png: the walk's standing pose. Run prompts.py {src / 'stand.png'} {src} --pose stand "
                              "and regenerate the other videos from the new start.png in loop mode: they then all "
                              "start and end on this pose (no stand-up, no ghosting where clips join).")
            ref = cs[0]["frames"][0]   # the idle pose is the seam every front clip lands on
        elif spec["mode"] == "lie":
            cs, note = cut_lie(v, ref, spec["cuts"])
            lie_ref = cs[1]["frames"][0]
        elif spec["mode"] == "lie_mid":
            cs, note = cut_lie_mid(v, ref, spec["cuts"], lie_ref)
        else:
            cs, note = cut_actions(v, ref, spec["cuts"])
        for c in cs:   # the same action in two chains (wave in actions_a and actions_d): keep both
            n, base = 2, c["id"]
            while any(o["id"] == c["id"] for o in clips):
                c["id"], n = f"{base}_{n}", n + 1
        clips += cs
        report.append(f"{cid}.mp4 ({v.n}f" + (f", stood up in the first {v.skipped}f" if v.skipped else "")
                      + (f", shifted {v.dx:+d}px to the shared pose" if v.dx else "")
                      + f"): {note}")
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
    if stand_note:
        print(stand_note)
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
