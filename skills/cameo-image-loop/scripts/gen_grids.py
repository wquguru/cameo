#!/usr/bin/env python3
"""Generate 2x2 animation grids for a batch via OpenRouter Design.

Usage:
    gen_grids.py --chars chars.json --out work/grids

chars.json format:
    {
      "nina": {
        "character": "a young ... (byte-identical wording reused for all prompts of the set)",
        "pose": "random" | "random:standing" | "random:sitting" | "random:lying"
                | "<explicit pose wording, appended after the character>",
        "actions": ["wave", "idle"]
      }
    }
If "pose" is omitted, the character string is used as-is (legacy: pose embedded
in the character wording). Wave/idle of one set always share the same drawn pose.
Poses with wave_ok=false in references/poses.json are auto-excluded when "wave"
is among the actions. --seed makes the draws reproducible.
Produces <name>_<action>_2x2.png per set. 2 attempts per grid, 3 parallel workers.
Writes poses_resolved.json (set -> drawn pose) next to the grids.
"""
import argparse, json, os, urllib.error, base64, time, random, urllib.request
from concurrent.futures import ThreadPoolExecutor

POSE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "..", "references", "poses.json")

API = "https://openrouter.ai/api/v1/images"

TAIL = """Sequential animation frames of ONE continuous motion, read left to right, top to bottom. Exactly four panels in a 2x2 arrangement, no more, no fewer.
Identical in every panel: camera, lens, framing, scale, lighting, face, hair, clothing. Only the limbs move as described.
The lowest point of the body touches the same horizontal ground line in every panel. Full body with a small margin around the person.
Photorealistic studio photo. Sharp, clean, well-defined silhouette edges; crisp hair outline; no motion blur.
No floor line, no shadow on the ground, no props, no text, no panel borders, no gutters, no labels.
isolated on a solid light-gray studio background, minimal clean background, sharp clean well-defined silhouette edges, strong contrast between subject and background, even studio lighting, tack-sharp focus."""

WAVE_BODY = """The arm on the LEFT side of the image waves; the body, head and legs do not move; the other arm stays as described in the pose.
Panel 1: waving hand raised beside the head, palm facing the camera, fingers upright.
Panel 2: same hand, fingers tilted slightly outward.
Panel 3: same hand, fingers tilted further outward.
Panel 4: same hand, fingers tilted slightly inward."""

IDLE_BODY = """A slow breath: Panel 1 exhale, body most relaxed and lowest. Panel 2 inhaling, chest slightly raised.
Panel 3 full inhale, chest raised highest. Panel 4 exhaling. The change between panels is very small; nothing else moves.
Her face is perfectly identical in every panel: same neutral calm expression, lips gently closed, same eyes; no mouth or eye movement at all."""

BODIES = {"wave": WAVE_BODY, "idle": IDLE_BODY}


def describe(e):
    """The API's own error message (e.g. a spending limit), not just the HTTP status."""
    if isinstance(e, urllib.error.HTTPError):
        try:
            return f"HTTP {e.code}: {json.loads(e.read())['error']['message']}"
        except Exception:
            pass
    return str(e)


def load_poses():
    with open(POSE_FILE) as f:
        return json.load(f)["poses"]


def resolve_pose(spec, poses, rng, wave):
    """Return (pose_id, category, wording) for a set.

    spec None -> legacy: pose is embedded in the character string (returns None).
    "random" / "random:<category>" -> draw from the pool (wave_ok=false excluded
    when wave is in the actions). Any other string -> explicit wording as-is.
    """
    if spec is None:
        return None
    if not spec.startswith("random"):
        return ("explicit", "-", spec)
    cat = spec.split(":", 1)[1] if ":" in spec else None
    pool = [p for p in poses if (cat is None or p["category"] == cat)]
    if not pool:
        raise SystemExit(f"no poses match category '{cat}' in {POSE_FILE}")
    if wave:
        ok = [p for p in pool if p.get("wave_ok", True)]
        if ok:
            pool = ok
    p = rng.choice(pool)
    return (p["id"], p["category"], p["wording"])


def call(prompt, key):
    body = json.dumps({"model": "inclusionai/ming-image-0.1-design", "prompt": prompt}).encode()
    req = urllib.request.Request(API, data=body, method="POST",
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {key}",
                 "HTTP-Referer": "https://localhost", "X-Title": "ming cameo"})
    with urllib.request.urlopen(req, timeout=600) as r:
        resp = json.loads(r.read())
    d = resp["data"][0]
    if d.get("b64_json"):
        return base64.b64decode(d["b64_json"])
    url = d.get("url", "")
    if url.startswith("data:"):
        return base64.b64decode(url.split(",", 1)[1])
    with urllib.request.urlopen(url, timeout=300) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=None,
                    help="seed for random pose draws (reproducible)")
    args = ap.parse_args()
    specs = json.load(open(args.chars))
    bad = [(n, a) for n, s in specs.items() for a in s.get("actions", []) if a not in BODIES]
    if bad:
        raise SystemExit(f"unsupported actions (only {', '.join(BODIES)}): {bad}")
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        raise SystemExit("OPENROUTER_API_KEY is not set; run check_openrouter.sh")
    os.makedirs(args.out, exist_ok=True)
    poses = load_poses()

    # Resolve one pose per set (shared by all its actions), deterministic per seed.
    resolved = {}
    for name, s in specs.items():
        rng = random.Random(f"{args.seed}:{name}" if args.seed is not None else None)
        r = resolve_pose(s.get("pose"), poses, rng, "wave" in s.get("actions", []))
        resolved[name] = r
        if r is None:
            print(f"[{name}] pose: embedded in character (legacy)", flush=True)
        else:
            print(f"[{name}] pose: {r[0]} ({r[1]})", flush=True)
    # Merge with any existing record (subset re-runs must not clobber other sets).
    pr_path = os.path.join(os.path.dirname(args.out.rstrip("/")), "poses_resolved.json")
    merged = {}
    if os.path.exists(pr_path):
        try:
            merged = json.load(open(pr_path))
        except Exception:
            merged = {}
    for n, r in resolved.items():
        merged[n] = ({"pose_id": r[0], "category": r[1], "wording": r[2]} if r else
                     {"pose_id": "embedded", "category": "-", "wording": "-"})
    json.dump(merged, open(pr_path, "w"), indent=1, ensure_ascii=False)

    def gen(job):
        name, action, char, pose = job
        subject = f"{char}, {pose[2]}" if pose else char
        prompt = (f"A 2x2 grid of exactly four sequential animation frames of the same real person: {subject}.\n"
                  f"{BODIES[action]}\n{TAIL}")
        t0 = time.time()
        for attempt in range(2):
            try:
                img = call(prompt, key)
                break
            except Exception as e:
                print(f"[{name}_{action}] attempt {attempt+1} failed: {describe(e)}", flush=True)
                time.sleep(5)
        else:
            return False
        path = os.path.join(args.out, f"{name}_{action}_2x2.png")
        open(path, "wb").write(img)
        print(f"[{name}_{action}] saved {len(img)//1024}KB in {time.time()-t0:.0f}s", flush=True)
        return True

    jobs = [(n, a, s["character"], resolved[n]) for n, s in specs.items() for a in s["actions"]]
    with ThreadPoolExecutor(max_workers=3) as ex:
        ok = all(ex.map(gen, jobs))
    print("ALL DONE" if ok else "SOME FAILED", ok)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
