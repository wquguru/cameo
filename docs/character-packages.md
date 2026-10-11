# Character packages: how they are made

A single looping video can only stand in one place. A character that walks along the desktop, turns, lies down and performs needs what iStripper does: a library of short clips that start and end on shared poses, and a player that strings them into a show. This page records how such a library is produced and what was learned doing it. The format is in [package-spec.md](package-spec.md); the steps are in the `cameo-video-package` skill.

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
- The start image is the character on a flat chroma colour (green #00B140, blue #0047BB when the character wears green), standing neutrally with arms down. A waving start image makes every clip start and end waving.

Cutting (`cut_clips.py`) finds the parts without labels: frames like the first are standing, left/right-asymmetric frames are side, frames where the figure is much shorter are lying, and the rest between standing beats are actions.

### Image frames (experimental)

Before video, packages were drawn as sprite sheets by a local image model (WAI-ANIMA on ComfyUI): a turnaround sheet, a 6-frame walk sheet and a 4-frame sheet per action, split into figures and aligned. One sheet keeps a character consistent within itself, but sheets differ from each other (accessories come and go), actions are 4 frames played back and forth, and turns are faked by squashing. It works offline at no cost and is good for trying out the player; video is better in every other way. The tooling lives outside this repo.

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
