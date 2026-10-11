"""Shared helpers: cut out, place on the package canvas, measure poses, encode, write a package.

Canvas rules (docs/package-spec.md in the Cameo repo): fixed W x H, feet on the bottom row,
torso centre at W/2.
"""
import json, subprocess, tempfile
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 512, 832          # package canvas (headroom for jumps and raised arms)
FIG_H = 680              # standing height on the canvas
_sessions = {}


def cutout(src, model="birefnet-portrait", soft=True):
    """RGBA PIL image with the background removed.

    soft keeps the model's fractional alpha (smooth hair and edges, needed for video);
    the default hard mask suits splitting sprite sheets."""
    im = src if isinstance(src, Image.Image) else Image.open(src)
    given = None
    if "A" in im.getbands() and im.getextrema()[-1][0] < 255:
        # Already cut out: the colour under its transparent pixels is often the old background's
        # fringe, which convert("RGB") would bring back as a glow. Flatten onto grey, keep its alpha.
        given = np.array(im.convert("RGBA"))[:, :, 3]
        flat = Image.new("RGBA", im.size, (128, 128, 128, 255))
        flat.alpha_composite(im.convert("RGBA"))
        im = flat
    out = cutout_many([im], model, soft)[0]
    if given is not None:
        a = np.array(out)
        a[:, :, 3] = np.minimum(a[:, :, 3], given)
        out = Image.fromarray(a)
    return out


def cutout_many(images, model="birefnet-portrait", soft=True):
    """cutout() for many frames at once. model "vision" is macOS's own matting (matte.swift, ~0.2 s
    a frame); the others are rembg models (birefnet-portrait ~10 s a frame on the CPU)."""
    if model == "vision":
        outs = _vision([im.convert("RGB") for im in images])
    else:
        from rembg import new_session, remove
        if model not in _sessions:
            # CPU only: in a fresh venv onnxruntime prefers CoreML, whose Neural Engine compile can hang
            # for good at 0% CPU on these large models.
            _sessions[model] = new_session(model, providers=["CPUExecutionProvider"])
        outs = [remove(im.convert("RGB"), session=_sessions[model], post_process_mask=not soft) for im in images]
    res = []
    for out in outs:
        a = np.array(out.convert("RGBA"))
        a[:, :, 3][a[:, :, 3] < 12] = 0   # faint haze
        res.append(Image.fromarray(a))
    return res


def _vision(images):
    """Run matte.swift over the frames, compiled once into ~/.cache (rebuilt when the source changes)."""
    src = Path(__file__).with_name("matte.swift")
    exe = Path.home() / ".cache" / "cameo-video-package" / "matte"
    if not exe.exists() or exe.stat().st_mtime < src.stat().st_mtime:
        exe.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["swiftc", "-O", "-o", str(exe), str(src)], check=True, capture_output=True)
    with tempfile.TemporaryDirectory() as tmp:
        ind, outd = Path(tmp, "in"), Path(tmp, "out")
        ind.mkdir(); outd.mkdir()
        for k, im in enumerate(images):
            im.save(ind / f"{k:05d}.png")
        subprocess.run([str(exe), str(ind), str(outd)], check=True)
        return [Image.open(outd / f"{k:05d}.png").copy() for k in range(len(images))]


def bbox(im, thr=24):
    a = np.array(im)[:, :, 3] > thr
    ys, xs = np.where(a)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def anchor_x(im, band=(0.30, 0.55), thr=24):
    """Horizontal centre of opaque pixels in the torso band of the figure."""
    a = np.array(im)[:, :, 3] > thr
    x0, y0, x1, y1 = bbox(im, thr)
    h = y1 - y0
    rows = a[y0 + int(h * band[0]): y0 + int(h * band[1])]
    xs = np.where(rows.any(axis=0))[0]
    cols = rows.sum(axis=0)
    return float((np.arange(len(cols)) * cols).sum() / max(cols.sum(), 1))


def place(im, W, H, scale, ax=None, ground=None):
    """Scale `im` by `scale`, put its ground line on the bottom row and `ax` at W/2."""
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    if ax is None:
        ax = anchor_x(im)
    else:
        ax *= scale
    if ground is None:
        ground = bbox(im)[3]
    else:
        ground *= scale
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(im, (round(W / 2 - ax), round(H - ground)))
    return canvas


def checker(im, size=16):
    w, h = im.size
    yy, xx = np.mgrid[0:h, 0:w]
    c = np.where(((yy // size + xx // size) % 2)[..., None] == 0, 200, 150).astype(np.uint8)
    bg = Image.fromarray(np.repeat(c, 3, axis=2)).convert("RGBA")
    bg.alpha_composite(im)
    return bg.convert("RGB")


def sheet(frames, out, cell_h=256, cols=8):
    """Contact sheet on a checkerboard, small, for cheap visual QC."""
    cells = []
    for f in frames:
        im = f if isinstance(f, Image.Image) else Image.open(f).convert("RGBA")
        s = cell_h / im.height
        cells.append(checker(im.resize((max(1, round(im.width * s)), cell_h), Image.LANCZOS)))
    cw = max(c.width for c in cells)
    rows = (len(cells) + cols - 1) // cols
    S = Image.new("RGB", (cw * min(cols, len(cells)), cell_h * rows), (255, 255, 255))
    for i, c in enumerate(cells):
        S.paste(c, ((i % cols) * cw, (i // cols) * cell_h))
    S.save(out, quality=85)
    return out


def encode(frames, out, fps):
    """ProRes 4444 with alpha from a list of RGBA images."""
    with tempfile.TemporaryDirectory() as d:
        for i, f in enumerate(frames):
            (f if isinstance(f, Image.Image) else Image.open(f)).save(f"{d}/f{i:04d}.png")
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", f"{d}/f%04d.png",
                        "-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le",
                        "-alpha_bits", "16", "-vendor", "apl0", out], check=True)
    return out


def key_color(im):
    """Background colour from the frame border, or None when it isn't a flat chroma colour."""
    a = np.asarray(im.convert("RGB")).astype(int)
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    k = np.median(border, axis=0)
    flat = np.median(np.abs(border - k).sum(axis=1)) < 30
    return k if flat and k.max() - k.min() > 80 else None


def dekey(cut, orig, key, band=3):
    """Clean a rembg cut-out against a known chroma background:
    drop leftover background patches inside the mask (gaps between hair and neck), then in a thin
    band along the edge derive soft alpha from the colour distance to the key and unmix the key
    colour out of the edge pixels (no green halo)."""
    from scipy import ndimage
    rgb = np.asarray(orig.convert("RGB")).astype(np.float32)
    out = np.asarray(cut).copy()
    alpha = out[:, :, 3].astype(np.float32) / 255
    key = np.asarray(key, np.float32)
    dist = np.linalg.norm(rgb - key, axis=2)
    # Leftover background inside the mask: key-coloured blobs bigger than a speck.
    near = (dist < 60) & (alpha > 0)
    lab, n = ndimage.label(near)
    if n:
        sizes = ndimage.sum(near, lab, range(1, n + 1))
        big = np.isin(lab, np.where(sizes >= 30)[0] + 1)
        alpha[big] = 0
    m = alpha > 0.5
    edge = ndimage.binary_dilation(m, iterations=band) & ~ndimage.binary_erosion(m, iterations=band)
    # The background as seen next to each edge pixel: video models don't keep the key exactly flat
    # (lighter towards the middle, drifting from frame to frame), and unmixing against the border
    # colour then leaves a rim in the opposite hue (yellow on blue).
    outside = (alpha < 0.02).astype(np.float32)
    near_bg = ndimage.uniform_filter(outside, 31)
    bg = np.stack([ndimage.uniform_filter(rgb[:, :, i] * outside, 31) for i in range(3)], -1)
    bg = np.where((near_bg > 0.05)[..., None], bg / np.maximum(near_bg, 1e-6)[..., None], key)
    # Likewise the figure's own colour just inside the edge. Alpha is where a pixel lies between the two;
    # a fixed distance scale assumes the figure is far from the key and, for muted clothes (sage on
    # blue), underestimates alpha, so unmixing overshoots into a dark rim of the opposite hue.
    inside = ndimage.binary_erosion(alpha > 0.98, iterations=band).astype(np.float32)
    near_fg = ndimage.uniform_filter(inside, 31)
    fgc = np.stack([ndimage.uniform_filter(rgb[:, :, i] * inside, 31) for i in range(3)], -1)
    fgc = fgc / np.maximum(near_fg, 1e-6)[..., None]
    d = fgc - bg
    span = (d * d).sum(axis=2)
    proj = np.clip(((rgb - bg) * d).sum(axis=2) / np.maximum(span, 1), 0, 1)
    dist = np.linalg.norm(rgb - bg, axis=2)
    soft = np.where((near_fg > 0.05) & (span > 40 ** 2), proj, np.clip((dist - 25) / 110, 0, 1))
    alpha = np.where(edge, np.minimum(soft, ndimage.binary_dilation(m, iterations=band)), alpha)
    # Unmix: observed = a*fg + (1-a)*bg  ->  fg = bg + (observed - bg)/a
    a3 = np.maximum(alpha, 0.15)[..., None]
    fg = np.clip(bg + (rgb - bg) / a3, 0, 255)
    col = np.where(edge[..., None], fg, out[:, :, :3])
    # Despill whatever key tint is left on the edge: cap the key's dominant channel.
    c = int(np.argmax(key))
    others = [i for i in range(3) if i != c]
    cap = col[:, :, others].max(axis=2)
    col[:, :, c] = np.where(edge, np.minimum(col[:, :, c], cap), col[:, :, c])
    out[:, :, :3] = col.astype(np.uint8)
    out[:, :, 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(out)


def symmetry(im):
    """Left/right mirror overlap of the upper body around the torso centre (front ~0.95, profile ~0.6)."""
    a = np.array(im)[:, :, 3] > 24
    x0, y0, x1, y1 = bbox(im)
    a = a[y0: y0 + int((y1 - y0) * 0.6)]
    ax = int(round(anchor_x(im)))
    w = min(ax, a.shape[1] - ax)
    l, r = a[:, ax - w: ax][:, ::-1], a[:, ax: ax + w]
    return float((l & r).sum() / max((l | r).sum(), 1))


def body_height(im):
    """Feet to top of head, ignoring raised hands (rows narrower than a head)."""
    a = np.array(im)[:, :, 3] > 24
    x0, y0, x1, y1 = bbox(im)
    widths = a[y0:y1].sum(axis=1)
    head = 0.09 * (y1 - y0)
    top = next((i for i, w in enumerate(widths) if w >= head), 0)
    return (y1 - y0) - top


def leg_spread(im):
    """Width of the opaque region in the bottom 10% of the figure."""
    a = np.array(im)[:, :, 3] > 24
    x0, y0, x1, y1 = bbox(im)
    band = a[y1 - max(4, (y1 - y0) // 10): y1]
    xs = np.where(band.any(axis=0))[0]
    return int(xs.max() - xs.min()) if len(xs) else 0


def breathe(base, n=12, amp=0.010):
    """Idle loop from one front keyframe: the upper body rises a little on the inhale."""
    a = np.array(base)
    x0, y0, x1, y1 = bbox(base)
    hip = y0 + int((y1 - y0) * 0.55)
    frames = []
    for i in range(n):
        s = amp * (1 - np.cos(2 * np.pi * i / n)) / 2
        top = Image.fromarray(a[:hip])
        th = top.height
        nh = round(th * (1 + s))
        top = top.resize((top.width, nh), Image.LANCZOS)
        im = Image.new("RGBA", base.size, (0, 0, 0, 0))
        im.alpha_composite(Image.fromarray(a[hip:]), (0, hip))
        im.alpha_composite(top, (0, hip - nh))
        frames.append(im)
    frames.append(frames[0])
    return frames


def facing(im):
    """'right' or 'left' for a side-view figure: the brighter face sits in front of the darker hair."""
    a = np.array(im).astype(float)
    x0, y0, x1, y1 = bbox(im)
    h = y1 - y0
    head = a[y0: y0 + int(h * 0.14)]
    alpha = head[:, :, 3] > 128
    lum = head[:, :, :3].mean(axis=2)
    ys, xs = np.where(alpha)
    if len(xs) == 0:
        return "right"
    cx = xs.mean()
    bright = alpha & (lum > np.percentile(lum[alpha], 70))
    bx = np.where(bright)[1].mean()
    return "right" if bx > cx else "left"


def write_package(root, name, clips, width=None):
    """clips: list of dicts (spec fields) with an extra 'frames' list of canvas images."""
    root = Path(root)
    (root / "clips").mkdir(parents=True, exist_ok=True)
    entries = []
    for c in clips:
        frames = c.pop("frames")
        c["file"] = f"clips/{c['id']}.mov"
        encode(frames, str(root / c["file"]), c["fps"])
        sheet(frames, str(root / f"sheet_{c['id']}.jpg"), cell_h=192, cols=12)
        entries.append(c)
    json.dump({"spec": 1, "name": name, "width": width or W, "height": H, "facing": "right", "clips": entries},
              open(root / "manifest.json", "w"), indent=1)


def load_clip(path, w, h):
    """Decode a package clip back into RGBA frames."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True, check=True).stdout
    n = len(raw) // (w * h * 4)
    arr = np.frombuffer(raw, np.uint8).reshape(n, h, w, 4)
    return [Image.fromarray(a) for a in arr]
