"""Make the start image and the copy-paste prompts for one character.

    prompts.py character.png <work-dir> [--duo]
Writes <work-dir>/start.png (the figure cut out and put on a flat chroma background, feet low,
headroom above for jumps) and <work-dir>/prompts.md (one prompt per chain video, see chains.py).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C
from chains import CHAINS, OPTIONAL, DUO_CHAINS, TAIL, NEG

KEYS = {"green": (0, 177, 64), "blue": (0, 71, 187)}
SIZE = (720, 1280)        # 9:16, what most video tools generate


def pick_key(fig):
    """Green screen unless the figure itself has a fair amount of green, olive included (then blue)."""
    hsv = np.asarray(fig.convert("RGB").convert("HSV")).astype(int)
    m = np.asarray(fig)[:, :, 3] > 128
    hue, sat, val = hsv[:, :, 0][m] * 360 / 255, hsv[:, :, 1][m], hsv[:, :, 2][m]
    greenish = ((hue > 60) & (hue < 170) & (sat > 50) & (val > 40)).mean() if m.any() else 0
    return "blue" if greenish > 0.05 else "green"


def start_image(src, out):
    fig = C.cutout(Image.open(src))
    x0, y0, x1, y1 = C.bbox(fig)
    fig = fig.crop((x0, y0, x1, y1))
    w, h = SIZE
    k = min(0.72 * h / fig.height, 0.8 * w / fig.width)   # room above for jumps and raised arms
    fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
    key = pick_key(fig)
    bg = Image.new("RGBA", SIZE, KEYS[key] + (255,))
    bg.alpha_composite(fig, ((w - fig.width) // 2, round(h * 0.94) - fig.height))
    bg.convert("RGB").save(out)
    return key


def block(cid, c):
    return (f"### {cid}  ({c['seconds']:g} s → {', '.join(c['cuts'])})\n\n"
            f"Save as `{cid}.mp4`\n\n```\n{c['prompt']}\n{TAIL}\n```\n")


def main(src, work, duo=False):
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    key = start_image(src, work / "start.png")
    specs = DUO_CHAINS if duo else CHAINS
    out = [f"# Video prompts\n",
           f"Start image for every video: `{work / 'start.png'}` ({key} screen). Image-to-video, one video per "
           "prompt, saved into this folder under the given name. If the tool only offers fixed lengths, round up; "
           "if it caps below the length, split the timeline at a standing beat into two videos that both start "
           "from the start image.\n",
           "| Video | Seconds | Clips |\n| --- | --- | --- |\n" +
           "\n".join(f"| `{k}` | {c['seconds']:g} | {', '.join(c['cuts'])} |" for k, c in specs.items()) + "\n",
           "Negative prompt (if the tool has one):\n\n```\n" + NEG + "\n```\n"]
    out += [block(k, c) for k, c in specs.items()]
    if not duo:
        out.append("## Optional, more actions\n")
        out += [block(k, c) for k, c in OPTIONAL.items()]
    (work / "prompts.md").write_text("\n".join(out))
    print(f"{work / 'start.png'} ({key} screen)\n{work / 'prompts.md'}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(*args[:2], duo="--duo" in sys.argv)
