# Character packages: how they are made

A single looping video can only stand in one place. A character that walks along the desktop, turns, lies down and performs needs what iStripper does: a library of short clips that start and end on shared poses, and a player that strings them into a show. This page records how such a library is produced (prompting, cutting, packaging) and what was learned doing it. The steps are in [../SKILL.md](../SKILL.md), the prompts in [prompts.md](prompts.md); the player's side of the format is `docs/package-spec.md` in the Cameo repo (https://github.com/wquguru/cameo/blob/main/docs/package-spec.md).

## The method

- **Poses are the joints.** `front` (standing, facing the viewer), `side` (walking profile, facing right), `lie` (lying on the stomach). Every clip goes from one pose to another (`transition`), loops on one (`idle`, `walk`), or leaves one and comes back to it (`action`). A clip can follow any clip that ends on its starting pose, so the scheduler (`CameoShow`) only needs the graph, not a script.
- **The player moves, the clips don't.** Walk clips walk in place; the window moves at the manifest's `speed`, mirrored for the other direction. This is what lets a few seconds of footage cover the whole screen.
- **Seams are made identical, not hidden.** Clips that end standing blend their last frames into one shared standing frame; loops are cut between their two best-matching frames; transitions enter a loop at its closest-matching phase. No cross-fades at play time.

## Producing the clips

### Video (the recommended route)

One image of the character → an image-to-video tool → a few **chain videos**, each holding several clips:

| Chain | Clips |
| --- | --- |
| walk | idle, turn_to_side, walk, turn_to_front |
| lie | lie_down, lie_idle, get_up |
| lie_phone | lie_phone |
| actions_a / actions_b | two actions each |

Why chains: separate clips each repeat the same warm-up (a walk clip from a standing image first has to turn; a lying clip first has to lie down), and both sides of a cut inside one video match exactly. Rules that make chains cuttable:

- Every chain starts and ends standing still facing the viewer, with a one-second standing beat between steps. Those beats are where it is cut.
- Prompts are generic and timed (`0–1.5 s: stands still… 1.5–2.5 s: turns…`): the image decides who it is, the prompt only motion and camera. Current tools follow a timeline better than "then… then…".
- The start image is the character on a flat chroma colour (green #00B140, blue #0047BB when the character wears green), standing neutrally with arms down. A waving start image makes every clip start and end waving; a sitting or other non-standing one gets prompts that stand up first (`chains.rise`).

Cutting (`cut_clips.py`) finds the parts without labels: frames like the first are standing, left/right-asymmetric frames are side, frames where the figure is much shorter are lying, and the rest between standing beats are actions.

### Image frames (experimental)

Before video, packages were drawn as sprite sheets by a local image model (WAI-ANIMA on ComfyUI): a turnaround sheet, a 6-frame walk sheet and a 4-frame sheet per action, split into figures and aligned. One sheet keeps a character consistent within itself, but sheets differ from each other (accessories come and go), actions are 4 frames played back and forth, and turns are faked by squashing. It works offline at no cost and is good for trying out the player; video is better in every other way. The tooling lives outside this repo.

## Cutting a chain video

`scripts/cut_clips.py`, per video, in this order:

1. **Preflight** (seconds): cut out the first and last frames (and, if the first doesn't stand, one every half second from 1 to 2.5 s). Stop unless the figure stands in one of them, judged against the last frame's height (every chain ends standing, so a chibi or an animal is judged against itself, not a fixed height/width ratio), with the whole body in frame; note a non-chroma background. `--force` overrides. A video that stands up first (a start image in another pose, `chains.rise`) is cut from its first steady standing stretch (97 % of the end's standing height for a third of a second), then from the stillest frame of the next second.
2. **Cut out every frame** at 12 fps with BiRefNet-portrait, soft alpha, on the CPU (~10 s/frame; the raw matte is cached next to the video). On a flat chroma background, also clean up against the key, keeping the model's alpha (never more opaque): drop key-coloured blobs the model kept (any size when close to the key, so shoelace loops and gaps between legs go; blue eyes are darker and greyer and stay), fade key-tinted slivers the model kept solid when they are large or long and thin (gaps between arm and body or fingers; an eye of the key's hue is small and round), cap the key channel everywhere (despill: at most 10 above the other channels, none above on the rim; the key is a colour the figure doesn't wear), and give semi-transparent pixels the colour of the nearest solid pixel. Deriving alpha or colour from the background instead (colour distance, unmixing, even against locally sampled colours) left a faint glow outside the figure and a rim of the wrong colour: a generated key is never quite flat, and the figure's colour next to an edge varies. The clean-up runs on every cut, so it can change without matting again.
3. **One transform for the whole video** (the camera is static): scale = standing height (feet-to-head over the closing standing frames, raised hands ignored; the tallest frames would count arms stretched overhead) → 680 px; floor = 95th percentile of the lowest opaque row; anchor = torso centre of the first frame. The package canvas is 832 high and as wide as the widest pose needs (≥ 512, one width for every clip).
4. **Label frames without labels**: *rest* = close to frame 0 (premultiplied colour + alpha at 1/8 size, adaptive threshold, runs shorter than 0.25 s smoothed away); *side* = left/right mirror overlap of the upper body 0.06 below the figure's own standing value (at most 0.88) and upright at standing height; when the standing pose itself is lopsided (an arm raised in a wave, overlap under 0.86) symmetry can't separate it from a profile, so side = shoulder rows narrower than 0.6 of standing; *lying* = under 0.75 of standing height and wider than tall.
5. **Cut by chain mode**:
   - walk: the longest side stretch; a stride loop of 0.6–1.6 s between its two best-matching frames; turn_to_side runs from the last rest frame to the loop's closest-matching phase, turn_to_front from the frame that matches the loop start again to the next rest. Speed from the stride, clamped to 220–480 px/s. Facing left → mirrored to face right.
   - lie: the same around the longest lying stretch (loop 0.8–2.5 s, or forward-and-back when it is short); lie_idle is an action on `lie` with `repeat: 3`.
   - lie_mid: the lying part as one `lie → lie` action, its ends blended into lie_idle's first frame.
   - actions: change against the first frame, measured on the most-changed patch (a wave moves one arm), above the midpoint between this video's rest level (start, end, stillest point between actions: a figure rarely lands exactly where it stood) and its motion; merged when an action paused midway, split at the stillest point when two ran together, so the count matches the prompt; widened to where the motion starts and ends, two frames of rest kept at each end.
6. **Seams**: every clip that ends standing blends its last 3 frames into one shared standing frame (the idle loop's first frame); every clip that starts there blends in from it. Loops repeat their first frame at the end (the player drops it).
7. **Report** `<-- CHECK` for a non-standing start, a wrong action count or a figure touching the canvas side.

## Packaging

A package is a folder: `manifest.json`, `clips/<id>.mov` (ProRes 4444 with alpha, `yuva444p10le`), optional `poster.png`. The canvas is the same for every clip, feet on the bottom row, torso centre at `width/2`, side views facing right (the player mirrors). Each clip in the manifest: `id`, `file`, `kind` (`idle`, `walk`, `transition`, `action`), `from`/`to` pose, `loop`, `fps`, plus `speed` for walk and `repeat` for actions. The player picks clips by pose: any clip may follow one that ends on its `from`, and it routes through transitions to reach an action's pose, so every pose must be reachable from `front` (`scripts/check.py` tests this, idle presence and every clip's alpha). Without a walk clip the character stays in place.

Minimal manifest:

```json
{"spec": 1, "name": "Mia", "width": 512, "height": 832, "facing": "right", "clips": [
  {"id": "idle", "file": "clips/idle.mov", "kind": "idle", "from": "front", "to": "front", "loop": true, "fps": 12},
  {"id": "turn_to_side", "file": "clips/turn_to_side.mov", "kind": "transition", "from": "front", "to": "side", "loop": false, "fps": 12},
  {"id": "walk", "file": "clips/walk.mov", "kind": "walk", "from": "side", "to": "side", "loop": true, "fps": 12, "speed": 320},
  {"id": "turn_to_front", "file": "clips/turn_to_front.mov", "kind": "transition", "from": "side", "to": "front", "loop": false, "fps": 12},
  {"id": "wave", "file": "clips/wave.mov", "kind": "action", "from": "front", "to": "front", "loop": false, "fps": 12}
]}
```

## Cut-out: what works

| Tried | Result |
| --- | --- |
| Checkerboard "transparent" background | Worst: some tools paint transparency as a checkerboard; patches stay in gaps (hair–neck, between legs). Never feed a transparent PNG. |
| White background | White clothes, sneakers, silver hair merge into it; the white halo cannot be told from white clothing. |
| rembg `isnet-anime`, hard mask | Jagged, aliased edges with a ring of background. Fine for splitting sprite sheets, not for video. |
| rembg `isnet-general-use`, soft alpha | Smooth but slightly hazy edges; 1 s/frame. Fast fallback. |
| **rembg BiRefNet-portrait, soft alpha** | **Cleanest edges and hair; ~10 s/frame. The default.** |
| OpenRouter Design-Layer | Redraws the figure: stays aligned, but blurrier edges with a faint glow, 3–4× the pixel error of BiRefNet, ~16 s and one paid call per frame. Not worth it for video. |
| **Flat chroma background + BiRefNet + edge clean-up** | **Best.** With the background colour known, leftover background patches are removed and the colour spill is unmixed from the edge pixels (no green fringe). Plain chroma keying alone is worse: compressed video stores colour at half resolution, which blurs a pure colour key's edges. |

## Other lessons

- **Walk speed** comes from the stride (feet apart at contact minus a foot, two steps per cycle) and is clamped to 220–480 canvas px/s: a bad estimate (few frames, three-quarter views) makes the figure skate.
- **Two characters drawn together blend** (outfits swap between them, figures merge), with image and video models alike. A duo is staged from two single packages on a 1024-wide canvas, with scripted shoves, hops and chases on top; real contact needs duo chain videos started from that composed frame.
- **Lying needs room.** A prone figure with raised lower legs is about as long as it is tall standing, wider than a 512 canvas; the cutter widens the package canvas to the widest pose (one width for every clip).
- **Scale from standing, not from the first frame.** A video that starts sitting would otherwise be scaled up to standing height; the cutter takes the standing height across the whole video and the lowest foot position as the floor.
- **Fail fast.** Cutting costs about 10 s per frame, so the cutter first checks each video's first frame (standing, whole body in frame, flat background) and stops in seconds when a video doesn't start like a chain.
- **Run matting on the CPU.** In a fresh environment onnxruntime picks CoreML first, and its Neural Engine compile can hang indefinitely at 0% CPU on BiRefNet.
- **Memory.** A package is decoded once and kept LZ4-packed; only the clip on screen is unpacked, as IOSurfaces Core Animation shows without CPU colour conversion. A two-character package went from 595 MB to about 250 MB this way.
- **Review cheaply.** Contact sheets of every clip at ~120 px rows catch almost every problem (halos, missing limbs, a loop that jumps) without watching anything.
