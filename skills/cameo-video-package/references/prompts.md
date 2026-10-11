# Chain video prompts

Generated from `scripts/chains.py` by `prompts.py --reference`; edit the beats there, not here. Use them image-to-video with the start image from `prompts.py` (flat chroma background, figure standing neutrally). Every chain starts and ends standing still facing the viewer, with standing beats between steps, and walking happens in place: that is what the cutter relies on.

Every prompt ends with:

```
Static camera, locked-off shot, no zoom, no pan. Full body visible, feet always in frame. Keep the plain solid chroma-key background of the input image: one flat color, evenly lit, no shadows, no gradient, no floor. Keep the exact art style, colors and design of the input image.
```

Negative prompt (if the tool has one):

```
camera movement, zoom, pan, cut, scene change, background objects, floor, floor shadow, gradient background, checkerboard, transparency grid, white background, green spill, cropped feet, extra limbs, deformed hands, morphing clothes, color change, text, watermark, blurry, child, loli, underage
```

## One character

| Video | Seconds | Clips |
| --- | --- | --- |
| `walk` | 8.5 | idle, turn_to_side, walk, turn_to_front |
| `lie` | 9 | lie_down, lie_idle, get_up |
| `lie_phone` | 9 | lie_phone |
| `actions_a` | 7 | wave, bow |
| `actions_b` | 6.5 | jump, spin |
| `actions_c` | 7 | cheer, stretch |
| `actions_d` | 8 | dance, wave |

### walk

```
A single character, full body, on a plain solid-color background. 8.5 seconds, one continuous shot.
0–1.5 s: The character stands still facing the viewer in the starting pose, breathing softly.
1.5–2.5 s: The character turns 90 degrees in place to profile, facing right.
2.5–6.5 s: The character walks to the right in place, as if on a treadmill: four steady strides, arms swinging opposite to the legs, the body staying at the same spot in the frame.
6.5–7.5 s: The character stops and turns back to face the viewer.
7.5–8.5 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### lie

```
A single character, full body, on a plain solid-color background. 9 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–3 s: The character kneels down and lies on the stomach, head on the right and feet on the left, propped on the elbows with the chin resting in both hands, lower legs bent up in the air.
3–6 s: The character stays lying there, smiling at the viewer and lazily swinging the lower legs back and forth; the body does not move from its spot.
6–8 s: The character pushes up, kneels and stands up facing the viewer.
8–9 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### lie_phone

```
A single character, full body, on a plain solid-color background. 9 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–3 s: The character kneels down and lies on the stomach, head on the right and feet on the left, propped on the elbows, lower legs bent up in the air.
3–6 s: The character takes out a smartphone, looks at it with both hands, giggles at the screen while the legs kick slowly, then puts it away and rests the chin in both hands.
6–8 s: The character pushes up, kneels and stands up facing the viewer.
8–9 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### actions_a

```
A single character, full body, on a plain solid-color background. 7 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–3 s: The character looks at the viewer, raises the right hand and waves three times, then lowers the arm.
3–4 s: The character stands still facing the viewer in the starting pose, breathing softly.
4–6 s: The character puts the hands together in front, bows politely from the waist, then straightens up.
6–7 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### actions_b

```
A single character, full body, on a plain solid-color background. 6.5 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–2.5 s: The character bends the knees, jumps straight up with both arms raised and lands softly on the same spot.
2.5–3.5 s: The character stands still facing the viewer in the starting pose, breathing softly.
3.5–5.5 s: The character spins around once on the spot with arms outstretched, hair and clothes flowing, ending facing the viewer.
5.5–6.5 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### actions_c

```
A single character, full body, on a plain solid-color background. 7 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–2.5 s: The character pumps one fist in the air twice with an excited open-mouthed smile, then lowers it.
2.5–3.5 s: The character stands still facing the viewer in the starting pose, breathing softly.
3.5–6 s: The character interlocks the fingers, stretches both arms high above the head with eyes closed, then relaxes.
6–7 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

### actions_d

```
A single character, full body, on a plain solid-color background. 8 seconds, one continuous shot.
0–1 s: The character stands still facing the viewer in the starting pose, breathing softly.
1–4 s: The character does a short playful dance, stepping side to side and spreading the arms, ending facing the viewer.
4–5 s: The character stands still facing the viewer in the starting pose, breathing softly.
5–7 s: The character looks at the viewer, raises the right hand and waves three times, then lowers the arm.
7–8 s: The character stands still facing the viewer in the starting pose, breathing softly.
```

## Two characters

Start image: the first idle frame of a composed duo package (`compose_duo.py`), flattened onto the chroma colour.

| Video | Seconds | Clips |
| --- | --- | --- |
| `duo_a` | 8 | bump, high_five |
| `duo_b` | 9.5 | tickle, pillow_fight |

### duo_a

```
Two characters standing side by side, full body, on a plain solid-color background. 8 seconds, one continuous shot.
0–1 s: Both stand still side by side facing the viewer, breathing softly.
1–4 s: The one on the left playfully bumps a hip into the one on the right, who stumbles a step sideways, laughs and pushes back.
4–5 s: Both stand still side by side facing the viewer, breathing softly.
5–7 s: Both turn slightly toward each other, give a big high five with raised hands, then face the viewer again.
7–8 s: Both stand still side by side facing the viewer, breathing softly.
```

### duo_b

```
Two characters standing side by side, full body, on a plain solid-color background. 9.5 seconds, one continuous shot.
0–1 s: Both stand still side by side facing the viewer, breathing softly.
1–4 s: The one on the right tickles the one on the left, who squirms and laughs, then tickles back.
4–5 s: Both stand still side by side facing the viewer, breathing softly.
5–8.5 s: Both pick up white pillows, swing them at each other so the pillows hit shoulders softly, laugh, then drop the pillows.
8.5–9.5 s: Both stand still side by side facing the viewer, breathing softly.
```
