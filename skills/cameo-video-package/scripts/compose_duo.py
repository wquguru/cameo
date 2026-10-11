"""Compose a two-character package from two finished single packages.

    compose_duo.py <left-package> <right-package> <out-package> <Name>
Anima can't keep two characters apart in one sheet (outfits blend), so the duo
is staged like an iStripper group scene: each performer plays her own clips on a
shared 1024-wide canvas, and the play-fight is scripted motion on top.
"""
import json, math, sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as A
from common import load_clip

A.W = 1024
XL, XR = 90, 422          # where each 512-wide performer canvas sits
FPS = 8


def load(pkg):
    pkg = Path(pkg)
    m = json.load(open(pkg / "manifest.json"))
    out = {}
    for c in m["clips"]:
        fr = load_clip(pkg / c["file"], m["width"], m["height"])
        if c.get("loop", c["kind"] in ("idle", "walk")) and len(fr) > 1:
            fr = fr[:-1]   # looping clips repeat their first frame at the end
        out[c["id"]] = (c, fr)
    return out


def at(clip, i, fps=FPS, loop=True):
    """Frame of `clip` shown at output frame i (output runs at `fps`)."""
    c, fr = clip
    k = int(i / fps * c["fps"])
    return fr[k % len(fr)] if loop else fr[min(k, len(fr) - 1)]


def frame(l, r, dl=(0, 0), dr=(0, 0), right_on_top=False):
    can = Image.new("RGBA", (A.W, A.H), (0, 0, 0, 0))
    layers = [(l, XL + dl[0], dl[1]), (r, XR + dr[0], dr[1])]
    for im, x, y in (layers if right_on_top else layers[::-1]):
        lay = Image.new("RGBA", can.size, (0, 0, 0, 0))
        lay.paste(im, (int(x), int(y)))
        can = Image.alpha_composite(can, lay)
    return can


def ease(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def hop(t, h=40):
    return -h * math.sin(math.pi * max(0.0, min(1.0, t)))


def main(left, right, out, name):
    L, R = load(left), load(right)
    clips = []

    n = 24
    clips.append({"id": "idle", "kind": "idle", "from": "front", "to": "front", "loop": True, "fps": FPS,
                  "frames": [frame(at(L["idle"], i), at(R["idle"], i + 9)) for i in range(n)] +
                            [frame(at(L["idle"], 0), at(R["idle"], 9))]})

    # Walk: the right one leads, the left one follows; both cycles stretched to the leader's length.
    cr, fr_r = R["walk"]
    cl, fr_l = L["walk"]
    n = len(fr_r)
    wf = [frame(fr_l[int(i * len(fr_l) / n)], fr_r[i]) for i in range(n)]
    clips.append({"id": "walk", "kind": "walk", "from": "side", "to": "side", "loop": True, "fps": cr["fps"],
                  "speed": round((cl["speed"] + cr["speed"]) / 2), "frames": wf + [wf[0]]})

    for t in ("turn_to_side", "turn_to_front"):
        c = R[t][0]
        k = max(len(L[t][1]), len(R[t][1]))
        clips.append({"id": t, "kind": "transition", "from": c["from"], "to": c["to"], "loop": False, "fps": c["fps"],
                      "frames": [frame(L[t][1][min(i, len(L[t][1]) - 1)], R[t][1][min(i, len(R[t][1]) - 1)])
                                 for i in range(k)]})

    # Bump: left shoves right, right staggers and hops back, then shoves back.
    f = []
    for i in range(32):
        a, b = at(L["idle"], i), at(R["idle"], i + 9)
        if i < 6:                       # left sidles over
            dl, dr = (110 * ease(i / 5), 0), (0, 0)
        elif i < 12:                    # contact: right is knocked away with a hop
            t = (i - 6) / 5
            dl, dr = (110 * (1 - 0.3 * t), 0), (120 * ease(t), hop(t))
        elif i < 20:                    # right charges back, left knocked away
            t = (i - 12) / 7
            dl, dr = (77 - 190 * ease(t), hop(max(0, t - 0.4) / 0.6, 30)), (120 - 230 * ease(t), 0)
        else:                           # both settle back to their spots
            t = (i - 20) / 11
            dl, dr = (-113 * (1 - ease(t)), 0), (-110 * (1 - ease(t)), 0)
        f.append(frame(a, b, dl, dr, right_on_top=12 <= i < 20))
    clips.append({"id": "bump", "kind": "action", "from": "front", "to": "front", "loop": False, "fps": FPS, "frames": f})

    # Wave together: they lean in toward each other while both wave.
    if "wave" in L and "wave" in R:
        k = max(len(L["wave"][1]), len(R["wave"][1])) * FPS // L["wave"][0]["fps"]
        f = []
        for i in range(k):
            t = math.sin(math.pi * i / (k - 1))
            f.append(frame(at(L["wave"], i, loop=False), at(R["wave"], i, loop=False), (70 * t, 0), (-70 * t, 0)))
        clips.append({"id": "wave_together", "kind": "action", "from": "front", "to": "front", "loop": False,
                      "fps": FPS, "frames": f})

    # Show-off: each does her own move at once (first non-wave action of each).
    la = next((a for a in L if L[a][0]["kind"] == "action" and a != "wave"), None)
    ra = next((a for a in R if R[a][0]["kind"] == "action" and a != "wave"), None)
    if la and ra:
        k = max(len(L[la][1]) * FPS // L[la][0]["fps"], len(R[ra][1]) * FPS // R[ra][0]["fps"])
        clips.append({"id": "show_off", "kind": "action", "from": "front", "to": "front", "loop": False, "fps": FPS,
                      "frames": [frame(at(L[la], i, loop=False), at(R[ra], i, loop=False)) for i in range(k)]})

    # Chase (side view): the follower closes in, the leader skips ahead, the gap resets.
    f = []
    for i in range(24):
        a, b = at(L["walk"], i, cl["fps"]), at(R["walk"], i, cl["fps"])
        if i < 12:
            dl, dr = (200 * ease(i / 11), 0), (0, 0)
        else:
            t = (i - 12) / 11
            dl, dr = (200 * (1 - ease(t)), 0), (90 * math.sin(math.pi * t), hop(min(1, t * 2), 45))
        f.append(frame(a, b, dl, dr))
    clips.append({"id": "chase", "kind": "action", "from": "side", "to": "side", "loop": False, "fps": cl["fps"],
                  "frames": f})

    poster = clips[0]["frames"][0]
    A.write_package(out, name, clips, width=A.W)
    poster.save(Path(out) / "poster.png")
    print(", ".join(f"{c['id']}" for c in clips))


if __name__ == "__main__":
    main(*sys.argv[1:5])
