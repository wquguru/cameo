"""Make the start image and the copy-paste prompts for one character.

    prompts.py character.png <work-dir> [--duo] [--max-seconds N] [--key green|blue] [--pose stand|other]
    prompts.py --reference [out.md]      # rewrite references/prompts.md from chains.py
Writes <work-dir>/start.png (the figure cut out and put on a flat chroma background, feet low,
headroom above for jumps) and <work-dir>/prompts.md (one prompt per chain video, see chains.py).
--max-seconds N retimes every chain to fit a tool that caps video length (Grok 6, Kling 5); see chains.fit.
--pose overrides the guess whether the figure stands (taller than 1.5x its width): a chibi or an animal
standing is wider than that, a figure in another pose gets prompts that stand up first (chains.rise).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C
from chains import CHAINS, OPTIONAL, DUO_CHAINS, TAIL, NEG, RISE, fit, rise

KEYS = {"green": (0, 177, 64), "blue": (0, 71, 187)}
SIZE = (720, 1280)        # 9:16, what most video tools generate


def pick_key(fig):
    """Green screen unless the figure itself has a fair amount of green, olive and muted sage included
    (then blue): despill against a green key greys out green clothes' edges and leaves a magenta rim."""
    hsv = np.asarray(fig.convert("RGB").convert("HSV")).astype(int)
    m = np.asarray(fig)[:, :, 3] > 128
    hue, sat, val = hsv[:, :, 0][m] * 360 / 255, hsv[:, :, 1][m], hsv[:, :, 2][m]
    greenish = ((hue > 60) & (hue < 170) & (sat > 25) & (val > 40)).mean() if m.any() else 0
    return "blue" if greenish > 0.05 else "green"


def start_image(src, out, key=None, pose=None):
    """Returns (key colour name, whether the figure stands)."""
    fig = C.cutout(Image.open(src))
    x0, y0, x1, y1 = C.bbox(fig)
    fig = fig.crop((x0, y0, x1, y1))
    standing = pose == "stand" if pose else fig.height >= 1.5 * fig.width
    w, h = SIZE
    # Room above for jumps and raised arms; a figure that isn't standing yet gets room to stand up in.
    k = min(0.72 * h / fig.height / (1 if standing else 1.8), 0.8 * w / fig.width)
    fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
    key = key or pick_key(fig)
    bg = Image.new("RGBA", SIZE, KEYS[key] + (255,))
    bg.alpha_composite(fig, ((w - fig.width) // 2, round(h * 0.94) - fig.height))
    bg.convert("RGB").save(out)
    return key, standing


def block(cid, c, note=""):
    return (f"### {cid}  ({c['seconds']:g} s → {', '.join(c['cuts'])})\n\n"
            f"Save as `{cid}.mp4`" + (f" (note: {note})" if note else "") + f"\n\n```\n{c['prompt']}\n{TAIL}\n```\n")


def fitted(specs, limit):
    """{id: (chain, note)}, retimed to limit seconds when given."""
    return {k: fit(c, limit) if limit else (c, "") for k, c in specs.items()}


def main(src, work, duo=False, limit=None, key=None, pose=None):
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    key, standing = start_image(src, work / "start.png", key, pose)
    up = (lambda d: {k: rise(c) for k, c in d.items()}) if not (standing or duo) else (lambda d: d)
    fits = fitted(up(DUO_CHAINS if duo else CHAINS), limit)
    extra = {} if duo else fitted(up(OPTIONAL), limit)
    specs = {k: c for k, (c, _) in fits.items()}
    out = [f"# Video prompts\n",
           f"Start image for every video: `{work / 'start.png'}` ({key} screen). Image-to-video, one video per "
           "prompt, saved into this folder under the given name. If the tool only offers fixed lengths, round up; "
           "if it caps below the length, split the timeline at a standing beat into two videos that both start "
           "from the start image.\n",
           "| Video | Seconds | Clips |\n| --- | --- | --- |\n" +
           "\n".join(f"| `{k}` | {c['seconds']:g} | {', '.join(c['cuts'])} |" for k, c in specs.items()) + "\n",
           "Negative prompt (if the tool has one):\n\n```\n" + NEG + "\n```\n"]
    out.insert(1, "The figure stands: use the tool's loop mode (image starts and ends the video) if it has one, "
                  "else first-frame mode.\n" if standing or duo else
                  "The figure isn't standing, so every video starts by standing up (the cutter skips that part). "
                  "Use first-frame mode, not loop mode. A standing start image gives cleaner seams and more time "
                  "for the motion.\n")
    if limit:
        out.insert(1, f"Retimed to fit {limit:g} s videos: standing beats are shorter and motion faster than the "
                      "full-length prompts in references/prompts.md. Set the tool to its longest length.\n")
    out += [block(k, c, n) for k, (c, n) in fits.items()]
    if extra:
        out.append("## Optional, more actions\n")
        out += [block(k, c, n) for k, (c, n) in extra.items()]
    (work / "prompts.md").write_text("\n".join(out))
    how = "given" if pose else "guessed from its shape; --pose stand|other if that's wrong"
    print(f"{work / 'start.png'} ({key} screen, figure {'standing' if standing or duo else 'not standing'}: {how})\n"
          f"{work / 'prompts.md'}")


def reference(out):
    """The generic prompts as a readable reference (references/prompts.md), no image needed."""
    def table(specs):
        return ("| Video | Seconds | Clips |\n| --- | --- | --- |\n" +
                "\n".join(f"| `{k}` | {c['seconds']:g} | {', '.join(c['cuts'])} |" for k, c in specs.items()) + "\n")
    out_lines = ["# Chain video prompts\n",
                 "Generated from `scripts/chains.py` by `prompts.py --reference`; edit the beats there, not here. "
                 "Use them image-to-video with the start image from `prompts.py` (flat chroma background, figure "
                 "standing neutrally). Every chain starts and ends standing still facing the viewer, with standing "
                 "beats between steps, and walking happens in place: that is what the cutter relies on.\n",
                 "Start image in another pose (sitting, waving...): every prompt first gets a beat that stands up "
                 "(`chains.rise`), and the cutter skips it:\n\n```\n0–1.5 s: " + RISE + ".\n```\n",
                 "Every prompt ends with:\n\n```\n" + TAIL + "\n```\n",
                 "Negative prompt (if the tool has one):\n\n```\n" + NEG + "\n```\n",
                 "## One character\n", table({**CHAINS, **OPTIONAL})]
    out_lines += [f"### {k}\n\n```\n{c['prompt']}\n```\n" for k, c in {**CHAINS, **OPTIONAL}.items()]
    out_lines += ["## Two characters\n", "Start image: the first idle frame of a composed duo package "
                  "(`compose_duo.py`), flattened onto the chroma colour.\n", table(DUO_CHAINS)]
    out_lines += [f"### {k}\n\n```\n{c['prompt']}\n```\n" for k, c in DUO_CHAINS.items()]
    Path(out).write_text("\n".join(out_lines))
    print(out)


if __name__ == "__main__":
    argv = sys.argv[1:]
    limit = None
    if "--max-seconds" in argv:
        i = argv.index("--max-seconds")
        limit = float(argv[i + 1])
        del argv[i:i + 2]
    key = None
    if "--key" in argv:
        i = argv.index("--key")
        key = argv[i + 1]
        del argv[i:i + 2]
        assert key in KEYS, f"--key must be one of {', '.join(KEYS)}"
    pose = None
    if "--pose" in argv:
        i = argv.index("--pose")
        pose = argv[i + 1]
        del argv[i:i + 2]
        assert pose in ("stand", "other"), "--pose must be stand or other"
    args = [a for a in argv if not a.startswith("--")]
    if "--reference" in sys.argv:
        reference(args[0] if args else Path(__file__).resolve().parent.parent / "references" / "prompts.md")
    else:
        main(*args[:2], duo="--duo" in argv, limit=limit, key=key, pose=pose)
