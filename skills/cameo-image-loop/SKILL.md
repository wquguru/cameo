---
name: cameo-image-loop
description: Make a Cameo character from only a description, with no footage. Generates a 2x2 animation grid with Ming-Image Design via OpenRouter, cuts the person out of each frame with Design-Layer, aligns the frames and encodes a short looping ProRes 4444 .mov with real alpha (wave or idle), then checks it and adds it to Cameo. Use when the user wants a Cameo character / desktop pet / 桌宠 / 透明角色动画循环 but has no video; for a green-screen or alpha clip use the cameo-from-video skill instead.
---

# Make a Cameo character from a description

Cameo plays one looping `.mov` with alpha; the bottom edge of the frame is where the figure stands. This skill draws four frames of one motion, cuts the person out of each and loops them 1-2-3-4-3-2. Scripts live in `scripts/` next to this file; below, `<skill-dir>` is the directory containing this SKILL.md. Use that absolute path, since your working directory is usually the user's project. Work in a fresh folder (`work/` below).

Requires macOS with `ffmpeg` (`brew install ffmpeg`), Command Line Tools (`swift`) and Python 3 with Pillow and numpy (`python3 -m pip install --user pillow numpy`, or prefix each script with `uv run --with pillow --with numpy`).

## 0. API key (do this first)

Run `<skill-dir>/scripts/check_openrouter.sh`. If it prints `MISSING`, stop: ask the user to add `export OPENROUTER_API_KEY='...'` to `~/.zshrc` and open a new terminal. Never ask for the key in chat, print it or log it; the scripts read it from the environment.

API: `POST https://openrouter.ai/api/v1/images` with `inclusionai/ming-image-0.1-design` (grids, text only) and `inclusionai/ming-image-0.1-design-layer` (splits, takes `input_references`). Free tier: about 1000 requests a day.

## 1. Brief

Per set, agree on a character description (age, face, hair, outfit), a pose and the actions: `wave` and/or `idle` (walk is not supported). Write it to `work/chars.json`:

```json
{ "nina": { "character": "a young woman with ... in a yellow crop top, white shorts and white sneakers",
            "pose": "random:standing", "actions": ["wave", "idle"] } }
```

- The character wording is the only consistency lever (no reference images): keep it byte-identical across a set, without the pose in it.
- `pose`: explicit wording, or `random`, `random:standing`, `random:sitting`, `random:lying` (pool in `references/poses.json`; poses with `wave_ok: false` are skipped for wave). Omitting it means the pose is already in the character string.
- Default outfit theme is summer unless the user says otherwise. Swimwear is fine, but never bake scenery into the grid: it ruins the edges. A new outfit is a new set.

## 2. Generate the grids

```bash
python3 <skill-dir>/scripts/gen_grids.py --chars work/chars.json --out work/grids [--seed 7]
```

About 40 s per grid, 3 in parallel; writes `work/grids/<set>_<action>_2x2.png` and `work/poses_resolved.json`. Prompt templates: `references/prompts.md`.

## 3. QC every grid (never skip)

Look at each grid: exactly four panels in 2x2, one person per panel, the pose matches, face and outfit consistent. Regenerate anything else; never slice a bad grid (a 4x2 grid sliced as 2x2 puts two people in every frame). Sitting poses drift to cross-legged: say "NOT cross-legged" and accept after 2 retries.

## 4. Cut out the person

```bash
python3 <skill-dir>/scripts/slice_layer.py --dir work
```

Slices each grid into four cells (refuses non-square grids) and splits each with Design-Layer, keeping the layer with the most opaque pixels below 90%. About 15–20 s per cell, sequential, 3 retries on transient errors, safe to rerun; run it in the background for big batches.

## 5. Align and encode

```bash
python3 <skill-dir>/scripts/align_encode.py --dir work
```

Aligns frames 2–4 to frame 1 by ground line and torso centre (translation only), crops to the union, scales to at most 960 px tall and encodes `work/mov/<set>_2x2.mov` (ProRes 4444, wave 10 fps, idle 6 fps) plus a contact sheet `work/sheets/<set>.jpg`. Look at every sheet: the figure should not jump, and hands and hair should be whole.

## 6. Verify

```bash
swift <skill-dir>/scripts/verify.swift work/mov/<set>_2x2.mov preview.png
```

It must print `OK`; then look at `preview.png`. Layer redraws rather than mattes, so expect slight jitter in hair and face between frames; don't promise pixel-perfect edges.

## 7. Add it to Cameo

```bash
open -a Cameo work/mov/<set>_2x2.mov
```

If Cameo is not installed, point the user to https://github.com/wquguru/cameo/releases/latest. To hand over a batch, write `notes.md` (character table, timings, regenerations and known issues) next to `work/`, then `python3 <skill-dir>/scripts/package.py --root . --name <batch>` makes one zip with `mov/`, `sheets/`, `notes.md` and the sources under `originals/`. New versions get new file names.

## 8. Share (optional)

Suggest submitting it to the gallery: https://wquguru.github.io/cameo/#submit (own work only, CC BY 4.0; up to 10 s, at most 1080 px tall, under 20 MB). Characters that look like a real, identifiable person need that person's consent.
