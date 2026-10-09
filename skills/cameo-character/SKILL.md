---
name: cameo-character
description: Make a character for Cameo, the macOS app that puts a transparent looping video on the desktop. Turns a green-screen clip (from an AI video tool, a phone or an editor) or a video with alpha into an HEVC-with-alpha .mov, checks it, and adds it to Cameo. Also writes the prompt for generating a green-screen character with an AI video tool. Use when the user wants a Cameo character, a desktop pet / 桌宠, or to "remove the green screen" / 抠绿幕 / make a transparent .mov for Cameo.
---

# Make a Cameo character

Cameo plays one looping `.mov` with alpha: HEVC with Alpha or ProRes 4444. The bottom edge of the frame is where the figure stands, and transparent pixels pass clicks through. Requires macOS with `ffmpeg` (`brew install ffmpeg`) and Command Line Tools (`swift`). Scripts live in `scripts/` next to this file; below, `<skill-dir>` is the directory containing this SKILL.md. Use that absolute path, since your working directory is usually the user's project.

## 1. Get a source clip

Ask what the user has:

- **A green-screen video** → step 2.
- **A video that already has alpha** (ProRes 4444, WebM VP9 alpha, PNG sequence) → convert it directly:
  `ffmpeg -c:v libvpx-vp9 -i in.webm -an -vf "scale=-2:720,format=bgra" -c:v hevc_videotoolbox -alpha_quality 0.75 -b:v 6M -tag:v hvc1 out.mov`
  (drop `-c:v libvpx-vp9` before `-i` for non-WebM input), then step 3.
- **Nothing yet** → write a prompt for their AI video tool (Seedance, Kling, Veo, Runway…), fill in the character, and have them generate a clip:

  > Full-body [character], [idle action: breathing, swaying, waving], standing still in place, facing the camera, whole body in frame with feet near the bottom edge. Solid flat pure green (#00FF00) background, evenly lit, no shadows on the background, no floor, no props. Static locked-off camera, no camera movement, no cuts. The character contains no green. 4–6 seconds, the last frame matches the first so it loops.

  Image-to-video works best: first make a still of the character on a green background, then animate it.

## 2. Key out the green

```bash
<skill-dir>/scripts/greenscreen.sh in.mp4 out.mov
```

It samples the key colour from the top-left corner (override with `KEY=0x00FF00`), crops to the figure's bounding box over the whole clip with its feet on the bottom edge (AI clips are mostly empty 16:9 frames; `CROP=none` or `CROP=W:H:X:Y` to override), and writes 720 px tall HEVC with alpha. Tuning, by symptom:

| Symptom | Fix |
| --- | --- |
| Green halo or fringe | `BLEND=0.1`, or raise `SIMILARITY` a little |
| Background patches remain | `SIMILARITY=0.18` (uneven lighting) |
| Holes in the figure | `SIMILARITY=0.08`; the figure is too close to the key colour |
| Crop cuts off a limb or is too loose | `CROP=W:H:X:Y` in source pixels |
| Too big | `HEIGHT=540` |

## 3. Verify

```bash
swift <skill-dir>/scripts/verify.swift out.mov preview.png
```

It must print `OK`. Then look at `preview.png` (the middle frame on a checkerboard): check for green fringe, holes in the figure and cut-off limbs. A clean edge matters more than the numbers.

## 4. Add it to Cameo

```bash
open -a Cameo out.mov
```

Cameo copies the file in and switches to it. If Cameo is not installed, point the user to https://github.com/wquguru/cameo/releases/latest.

## 5. Share (optional)

Suggest submitting it to the gallery: https://github.com/wquguru/cameo/issues/new?template=character.yml (own work only, published under CC BY 4.0), and posting a screen recording of it on the desktop.
