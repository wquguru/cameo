---
name: cameo-video-package
description: Make a Cameo character that walks along the desktop, turns, lies down and performs actions, from one character image plus any image-to-video tool (Grok, Kling, Seedance, Veo, Wan…). Prepares a chroma-key start image and timed prompts for a few "chain" videos, then cuts the generated videos into a character package (manifest.json + ProRes 4444 clips: idle, walk, turns, lying, actions), checks it and adds it to Cameo. Use when the user wants a Cameo character that moves around / 在桌面上走动、趴下、做动作的角色 / an iStripper-style desktop character, or has such videos to cut; for a single looping clip use cameo-from-video instead.
---

# Make a walking Cameo character (package)

A package is a folder Cameo plays like iStripper: a library of short clips joined at shared poses (`front` standing, `side` walking, `lie` lying), picked by Cameo's scheduler, while the window walks along the screen bottom. How it is made (prompting, cutting, packaging, what was tried): [references/method.md](references/method.md). All prompts, readable without running anything: [references/prompts.md](references/prompts.md).

Several clips are generated in one video ("chain") and cut apart afterwards. That is cheaper (no repeated warm-up seconds) and the seams match, since both sides of a cut come from the same video. Every chain starts and ends standing still, facing the viewer, with a standing beat between steps; walking happens in place.

Requires macOS, `ffmpeg`, Command Line Tools (`swift`) and Python 3. Below, `<skill-dir>` is the directory containing this SKILL.md; use its absolute path.

## 1. Set up (once)

```bash
PY=$(<skill-dir>/scripts/setup.sh)
```

Creates a venv (rembg, scipy) and downloads the BiRefNet matting model (~1 GB, md5-checked). It prints the python path; if it prints `MISSING`/`FAIL`, fix that first.

## 2. Start image and prompts

Ask for one image of the character, full body, no cropping. Best is standing, arms down, facing the viewer: every clip starts and ends on that pose. Any other pose (sitting, waving) works too: `prompts.py` then has every video stand up first and the cutter skips that part, at the cost of 1.25 s per video and slightly looser seams between videos. It guesses the pose from the figure's shape and prints the guess; look at the image and pass `--pose stand` (a chibi, an animal) or `--pose other` when it's wrong. With a start image in another pose, have them make only `walk.mp4` first and cut it: the cutter then writes `work/<id>/stand.png`, the walk's standing pose; rerun `prompts.py work/<id>/stand.png work/<id> --pose stand` and have the other videos made from the new `start.png` in loop mode. Each stand-up ends a little differently, so videos that each stand up on their own ghost where their clips join.

```bash
$PY <skill-dir>/scripts/prompts.py character.png work/<id>
```

Writes `work/<id>/start.png` (figure cut out, on flat green #00B140, or blue #0047BB when the figure itself is green, muted sage included; `--key green|blue` overrides) and `work/<id>/prompts.md`. Give the user the prompts file. For each chain video they run image-to-video with `start.png` and that prompt, and save the result under the given name into `work/<id>/`:

| Video | Seconds | Clips cut from it |
| --- | --- | --- |
| `walk.mp4` (required) | 8.5 | idle, turn_to_side, walk, turn_to_front |
| `lie.mp4` | 9 | lie_down, lie_idle, get_up |
| `lie_phone.mp4` | 9 | lie_phone |
| `actions_a.mp4` | 7 | wave, bow |
| `actions_b.mp4` | 6.5 | jump, spin |

Each video adds clips. Without `walk.mp4` the character stays in place (idle comes from the start of another video), so make `walk` first. Tool tips: feed `start.png`, never a transparent PNG (some tools paint transparency as a checkerboard, others show the old background's fringe hidden under it as a glow); round fixed lengths up. If the tool caps below these lengths (Grok 6 s unless its longer option is chosen, Kling 5 s), rerun `prompts.py` with `--max-seconds N`: standing beats shorten and motion speeds up to fit, cutting is unchanged (cuts are found by pose, not time), and a chain squeezed below 60 % of its pace is flagged.

Image-to-video mode: with a standing start image use the tool's loop mode (the image starts and ends the video) if it has one, else first-frame mode; with any other pose use first-frame mode. `prompts.md` says which.

A user who already has a video: look at a few frames (`ffmpeg -i in.mp4 -vf fps=1,scale=-1:200,tile=10x1 -frames:v 1 strip.jpg`), decide which chain it matches and copy it in under that name. It can only be cut if it fits the chain rules:

- starts standing still, facing the viewer, or stands up within the first 2.5 s; ends standing
- the whole body stays in frame the whole time, with room above the head (no close-ups)
- the steps of one chain, in order, with standing beats between them

If it doesn't fit, say so and have them regenerate it from `start.png` with the matching prompt: cutting a misfit video gives a wrong scale and bad seams. A flat chroma background is strongly preferred (cleaner edges) but not required.

## 3. Cut into a package

```bash
$PY <skill-dir>/scripts/cut_clips.py work/<id> work/<id>/package "<Name>"
```

It first checks each video's first frame (seconds) and stops if a video isn't fully framed or doesn't stand by 2.5 s; `--force` cuts anyway. A video that starts in another pose is cut from its first steady standing stretch. Then about 10 s per frame of video (BiRefNet on the CPU; matting cached in `<video>.birefnet-portrait.matte/`, so reruns take seconds even after edge clean-up changes), so run it in the background for several videos. `--model isnet-general-use` is ten times faster with softer edges; `--model isnet-anime` suits flat anime art.

How it cuts: frames like the first one are "standing", lopsided frames are "side", short figures are "lying"; loops run between their best-matching frames, transitions enter and leave a loop at its closest phase, and clips ending on the standing pose blend into the same standing frame. On a flat chroma background it also removes leftover background patches and colour spill from the edges.

Read its report. The canvas widens by itself when a pose (lying) needs it. `<-- CHECK` means: the first frame isn't standing, action count differs from the prompt (an action was skipped or split) or a figure touches the canvas side (lying too long: use a start image with more side room, or accept it). `walk: no profile frames found` means the video never turned sideways: regenerate.

## 4. Check

```bash
$PY <skill-dir>/scripts/check.py work/<id>/package work/<id>/preview.jpg
```

Must end with `OK` (idle and walk present, every pose reachable from standing, every clip has real alpha). Then look at `preview.jpg`, one row per clip: edge halos, background patches, missing limbs, a walk loop that jumps. Keep image reads small.

## 5. Add it to Cameo

```bash
open -a Cameo work/<id>/package
```

Cameo copies the folder in and switches to it. To try a package without importing (development build): `CAMEO_PACKAGE=/abs/path/package .build/debug/Cameo`. With a locally built app: `open -a /path/to/Cameo.app work/<id>/package`. Not installed: https://github.com/wquguru/cameo/releases/latest (package support needs a build with the package player).

## 6. Share it in the gallery (optional)

Zip the package folder and submit the .zip at https://wquguru.github.io/cameo/#submit (or attach it to the GitHub submission form):

```bash
ditto -c -k --keepParent work/<id>/package "<Name>.zip"
```

The zip must be under 20 MB, every clip at most 10 s and 1080 px tall; the page checks it before uploading. A two-character canvas or many actions can go over: drop an action chain, or keep it for yourself.

## Two characters together (optional)

Video models blend two characters' outfits when drawn together, so a duo starts from two finished single packages placed side by side; play-fights are scripted motion on top:

```bash
$PY <skill-dir>/scripts/compose_duo.py work/a/package work/b/package work/duo/package "A & B"
```

For real contact (tickling, pillow fight), make a start image from the duo's first idle frame, generate the duo chains (`prompts.py <image> work/duo --duo`), and add them with `cut_clips.py work/duo work/duo/package X --duo`.
