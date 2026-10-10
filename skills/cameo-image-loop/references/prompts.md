# Prompt templates & API snippets

## Shared background/edge tail (C formula — append to every grid prompt)
```
Sequential animation frames of ONE continuous motion, read left to right, top to bottom. Exactly four panels in a 2x2 arrangement, no more, no fewer.
Identical in every panel: camera, lens, framing, scale, lighting, face, hair, clothing. Only the limbs move as described.
The lowest point of the body touches the same horizontal ground line in every panel. Full body with a small margin around the person.
Photorealistic studio photo. Sharp, clean, well-defined silhouette edges; crisp hair outline; no motion blur.
No floor line, no shadow on the ground, no props, no text, no panel borders, no gutters, no labels.
isolated on a solid light-gray studio background, minimal clean background, sharp clean well-defined silhouette edges, strong contrast between subject and background, even studio lighting, tack-sharp focus.
```

## Wave (2x2)
```
A 2x2 grid of exactly four sequential animation frames of the same real person: {CHARACTER}, {POSE}.
The arm on the LEFT side of the image waves; the body, head and legs do not move; the other arm stays as described in the pose.
Panel 1: waving hand raised beside the head, palm facing the camera, fingers upright.
Panel 2: same hand, fingers tilted slightly outward.
Panel 3: same hand, fingers tilted further outward.
Panel 4: same hand, fingers tilted slightly inward.
```
+ tail. Encode 1-2-3-4-3-2 @10fps.

## Idle (2x2)
```
A 2x2 grid of exactly four sequential animation frames of the same real person: {CHARACTER}, {POSE}.
A slow breath: Panel 1 exhale, body most relaxed and lowest. Panel 2 inhaling, chest slightly raised.
Panel 3 full inhale, chest raised highest. Panel 4 exhaling. The change between panels is very small; nothing else moves.
Her face is perfectly identical in every panel: same neutral calm expression, lips gently closed, same eyes; no mouth or eye movement at all.
```
+ tail. Encode 1-2-3-4-3-2 @6fps.

## Walk in place (3x3) — legacy, kept for reference
Nine panels, one full walk cycle left-to-right top-to-bottom; encode @12fps. 3x3 drifts more than 2x2; prefer 2x2 unless a longer cycle is needed.

## Summer outfit wording (default theme)
Keep the outfit description concrete and byte-identical across a set's prompts. Examples:
- "a yellow crop top, white shorts and white sneakers"
- "a light blue sleeveless summer dress and sandals"
- "a white linen short-sleeve shirt, khaki shorts and sandals"

## Design-Layer split prompt
```
Split this image into exactly 2 layers: 1. the person, 2. the background. Keep the original canvas size and the exact pixel position of everything. Do not move, resize or redraw the person.
```

## API calls (Python)

Design grid:
```python
import json, urllib.request, os
body = json.dumps({"model": "inclusionai/ming-image-0.1-design", "prompt": prompt}).encode()
req = urllib.request.Request("https://openrouter.ai/api/v1/images", data=body, method="POST",
    headers={"Content-Type": "application/json",
             "Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}",
             "HTTP-Referer": "https://localhost", "X-Title": "ming cameo"})
with urllib.request.urlopen(req, timeout=600) as r:
    resp = json.loads(r.read())
b64 = resp["data"][0]["b64_json"]  # or data[0]["url"] data-URL
```

Layer split (input_references = data-URL of the cell PNG):
```python
body = json.dumps({"model": "inclusionai/ming-image-0.1-design-layer",
    "prompt": LAYER_PROMPT,
    "input_references": [{"type": "image_url",
        "image_url": {"url": f"data:image/png;base64,{cell_b64}"}}]}).encode()
# response data[] may hold several layers; pick the one with the largest
# opaque fraction below 0.9 as the person layer
```

## Alignment algorithm
```python
def ground(im):  # lowest row with alpha > 10
def anchor(im):  # horizontal center of opaque pixels in the 35%-55% height band (torso)
# shift frames 2..4 by (anchor1-anchorN, ground1-groundN); translation only
# union bbox of all shifted frames; crop; if height > 960: scale to 960
```

## Encode
```bash
ffmpeg -y -framerate 10 -i fr/f%02d.png -c:v prores_ks -profile:v 4444 \
  -pix_fmt yuva444p10le -alpha_bits 16 -vendor apl0 mia_wave_2x2.mov
ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt \
  -of default=noprint_wrappers=1 mia_wave_2x2.mov   # expect yuva444p12le
```
