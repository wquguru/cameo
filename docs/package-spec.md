# Character package spec v1

A character is a folder. Production (frames → clips) and the player only meet here. How to produce one: [character-packages.md](character-packages.md) and the `cameo-video-package` skill.

```
<name>/
  manifest.json
  clips/<clip-id>.mov      # HEVC with Alpha or ProRes 4444, all the same canvas size
  poster.png               # optional, front neutral pose, for the library tile
```

## Canvas rules (production guarantees these)

- Every clip in a package has the same canvas `width` × `height` (512 × 832 for one character, 1024 × 832 for two).
- The feet touch the bottom edge (`baseline` = bottom row) in every frame.
- The body's anchor (torso centre) sits at horizontal centre `width/2` in neutral poses, so swapping clips never jumps.
- The first frame of a clip is the `from` pose keyframe and the last frame is the `to` pose keyframe, pixel-identical across clips. Any clip can follow any clip whose `from` equals its `to`.
- Side-view clips face `facing` (default `"right"`). The player mirrors horizontally to go the other way.

## manifest.json

```json
{
  "spec": 1,
  "name": "Nina",
  "width": 512, "height": 832,
  "facing": "right",
  "clips": [
    {"id": "idle",          "file": "clips/idle.mov",          "kind": "idle",       "from": "front", "to": "front", "loop": true,  "fps": 6},
    {"id": "walk",          "file": "clips/walk.mov",          "kind": "walk",       "from": "side",  "to": "side",  "loop": true,  "fps": 10, "speed": 95},
    {"id": "turn_to_front", "file": "clips/turn_to_front.mov", "kind": "transition", "from": "side",  "to": "front", "loop": false, "fps": 8},
    {"id": "turn_to_side",  "file": "clips/turn_to_side.mov",  "kind": "transition", "from": "front", "to": "side",  "loop": false, "fps": 8},
    {"id": "wave",          "file": "clips/wave.mov",          "kind": "action",     "from": "front", "to": "front", "loop": false, "fps": 10, "repeat": 2}
  ]
}
```

| Field | Meaning |
| --- | --- |
| `kind` | `idle` (default rest), `walk` (moves the window), `transition` (pose change), `action` (one-off performance), `drag` (optional, shown while dragged) |
| `from` / `to` | Neutral pose names. Free-form strings; `front` and `side` are the standard pair, `lie` (lying on the stomach) the usual third. A pose is reachable when transitions lead to it from `front`. |
| `loop` | true: may be repeated back to back. |
| `fps` | Playback frame rate; overrides the file's own if present. |
| `speed` | Walk only: horizontal ground speed in canvas pixels per second at native size. Player scales it with display size. |
| `repeat` | Action only: how many times to play in a row (default 1). |

Unknown fields are ignored; unknown kinds are skipped.

## Player behaviour (iStripper-style show)

A scheduler strings clips into a show: enter from a screen edge walking → stop at a random x → turn to front → idle a while → an action → idle → turn to side → walk somewhere else (or off-screen and back). Only legal transitions (`to` == next `from`) are chosen; when no direct edge exists, the shortest path through transitions is used. Click → play a random action at the next front pose. Drag → pause walking; release → resume.

## Player notes and optional additions (Cameo implementation)

- **Looping clips with `from` == `to`**: the last frame is a duplicate of the first (same keyframe), and the player drops it when looping so the seam doesn't hold the pose for two frames. (The placeholder generator emits N+1 frames for these.)
- **Mirroring**: clips whose `from` or `to` is not `front` are mirrored when the figure goes the other way; clips that only involve `front` are never mirrored (front is assumed symmetric). A package may not currently override this set.
- **`drag` clips** are accepted by the parser but ignored by the player (the current frame is held while dragging).
- **Missing optional fields**: `from`/`to` default to `front`; `loop` defaults to true for `idle`/`walk`, false otherwise; `fps` defaults to 10. `spec` defaults to 1 when absent.
- `poster.png` is not used yet; library tiles use the first frames of the `idle` clip.
- Memory: every clip is decoded once and kept LZ4-compressed (a mostly transparent 512x832 frame packs to a fraction of its 1.7 MB); only the clip on screen is held unpacked, as IOSurfaces. A few hundred frames per package is comfortable.
- Dev: `CAMEO_PACKAGE=/abs/path/to/package` shows that folder on launch without importing it.
