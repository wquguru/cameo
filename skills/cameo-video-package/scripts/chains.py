"""Chain videos: several clips generated in one video, cut apart afterwards.

Shared by video_prompts.py (writes the prompts) and cut_clips.py (cuts the videos).
Every chain starts and ends standing still facing the viewer (the "rest" pose), with a
rest between steps, so every cut is a seam the player can join.

mode tells cut_clips.py how to find the cuts:
  walk     rest | turn_to_side | walk (loop) | turn_to_front | rest      (profile frames = low symmetry)
  lie      rest | lie_down | lie_idle (loop) | get_up | rest             (lying frames = short figure)
  lie_mid  rest | ... | <lying part> | ... | rest   -> one lie->lie action
  actions  rest | action 1 | rest | action 2 | rest                     (rest = frames like frame 0)
"""

# Background: the keyframe sits on a flat chroma colour (green, or blue for green-clad characters).
# The image decides the colour; the prompt only says "keep it". A known flat colour lets the
# cutter remove the halo and leftover patches that rembg leaves on white or checkerboard.
# Edges: image-to-video tools often ignore alpha, so a cut-out PNG brings back the light fringe hidden
# under its transparent pixels, and "keep the exact style" makes the model keep it on every frame.
# The prompt calls such a fringe an artefact and asks for flat front light, which also avoids rim light.
TAIL = ("Static camera, locked-off shot, no zoom, no pan. Full body visible, feet always in frame. "
        "Keep the plain solid chroma-key background of the input image: one flat color, evenly lit, "
        "no shadows, no gradient, no floor. Soft, even, flat front lighting: no backlight, no rim light. "
        "Natural, sharp edges where the character meets the background, with no outline, halo or glow; "
        "if the input image shows a thin light outline around the character, it is a cutout artifact, "
        "leave it out from the first frame on. Keep the character's face, hair, clothes, colors and art "
        "style from the input image.")
NEG = ("camera movement, zoom, pan, cut, scene change, background objects, floor, floor shadow, gradient background, "
       "checkerboard, transparency grid, white background, green spill, white outline, sticker border, halo, glow, "
       "rim light, backlight, edge fringe, cropped feet, extra limbs, deformed hands, morphing clothes, "
       "color change, text, watermark, blurry, child, loli, underage")

# Action beats: (seconds, what happens). Each ends back in the standing pose.
ACT = {
    "wave":    (2.0, "looks at the viewer, raises the right hand and waves three times, then lowers the arm"),
    "bow":     (2.0, "puts the hands together in front, bows politely from the waist, then straightens up"),
    "jump":    (1.5, "bends the knees, jumps straight up with both arms raised and lands softly on the same spot"),
    "cheer":   (1.5, "pumps one fist in the air twice with an excited open-mouthed smile, then lowers it"),
    "stretch": (2.5, "interlocks the fingers, stretches both arms high above the head with eyes closed, then relaxes"),
    "spin":    (2.0, "spins around once on the spot with arms outstretched, hair and clothes flowing, ending facing the viewer"),
    "dance":   (3.0, "does a short playful dance, stepping side to side and spreading the arms, ending facing the viewer"),
}
DUO_ACT = {
    "bump":         (3.0, "the one on the left playfully bumps a hip into the one on the right, who stumbles a step sideways, laughs and pushes back"),
    "high_five":    (2.0, "both turn slightly toward each other, give a big high five with raised hands, then face the viewer again"),
    "tickle":       (3.0, "the one on the right tickles the one on the left, who squirms and laughs, then tickles back"),
    "pillow_fight": (3.5, "both pick up white pillows, swing them at each other so the pillows hit shoulders softly, laugh, then drop the pillows"),
}
# Between actions the arms must come all the way down: a model squeezed for time goes from one action
# into the next (hands already together for the bow), and the clips then can't join the shared pose.
REST = ("stands completely still, upright on both feet, facing the viewer, both arms hanging straight down at "
        "the sides as in the first frame, breathing softly")
DUO_REST = "both stand still, upright on both feet, side by side facing the viewer as in the first frame, breathing softly"


def prompt(beats, intro):
    """Intro sentence + a timed beat list; the times also tell cut_clips.py where to look."""
    t, lines = 0.0, []
    for sec, text in beats:
        lines.append(f"{t:g}–{t + sec:g} s: {text}.")
        t += sec
    return f"{intro} {t:g} seconds, one continuous shot.\n" + "\n".join(lines), t


def chain(mode, cuts, beats, intro="A single character, full body, on a plain solid-color background."):
    text, sec = prompt(beats, intro)
    return dict(mode=mode, cuts=cuts, seconds=sec, prompt=text, beats=beats, intro=intro)


def fit(c, limit):
    """The chain retimed to at most limit seconds, for tools that cap the length (Grok 6 s, Kling 5 s).
    The cutter finds cuts by pose, not by time, so only the pacing changes: standing beats shrink first
    (0.5 s at the ends, 1 s before a walk, 0.75 s between steps, 1.25 s to rise, still long enough to read as a pause), then the motion
    beats scale evenly, in quarter seconds. Returns (chain, note); note warns when motion runs below
    60 % of its pace, where the tool is better asked for the longer length or the chain split."""
    if c["seconds"] <= limit:
        return c, ""
    last = len(c["beats"]) - 1
    rest = [i for i, (_, t) in enumerate(c["beats"]) if " still, upright" in t]
    short = {i: 0.5 if i in (0, last) else 0.75 for i in rest}
    if c["mode"] == "walk" and rest:
        short[rest[0]] = 1   # the walk video's opening stand is where the breathing idle loop comes from
    if c["beats"][0][1] == RISE:
        short[0] = 1.25      # standing up from the start image: too fast and it blurs into the first step
    beats = [(min(sec, short.get(i, sec)), t) for i, (sec, t) in enumerate(c["beats"])]
    still = sum(sec for i, (sec, _) in enumerate(beats) if i in short)
    moving = sum(sec for i, (sec, _) in enumerate(beats) if i not in short)
    k = min(1, (limit - still) / moving)
    beats = [(sec if i in short else max(0.25, int(sec * k * 4) / 4), t) for i, (sec, t) in enumerate(beats)]
    out = chain(c["mode"], c["cuts"], beats, c["intro"])
    return out, (f"motion at {k:.0%} of its pace: ask for a longer video if the tool has one" if k < 0.6 else "")


RISE = ("The character gets up from the pose of the first frame and stands upright on both feet, facing the viewer, "
        "arms relaxed at the sides")


def rise(c):
    """The chain for a start image that isn't standing (sitting, lying, waving...): it first stands up,
    and every rest is that standing pose rather than the first frame. cut_clips.py skips the rise and
    cuts from the first steady standing stretch. Image-to-video in first-frame mode, not loop mode."""
    beats = [(1.5, RISE)] + [(sec, t.replace(" as in the first frame", "")) for sec, t in c["beats"]]
    return chain(c["mode"], c["cuts"], beats, c["intro"])


def actions(a, b):
    return chain("actions", [a, b], [(1, "The character " + REST), ACT[a][:1] + ("The character " + ACT[a][1],),
                                      (1, "The character " + REST), ACT[b][:1] + ("The character " + ACT[b][1],),
                                      (1, "The character " + REST)])


def duo(a, b):
    intro = "Two characters standing side by side, full body, on a plain solid-color background."
    return chain("actions", [a, b], [(1, DUO_REST[0].upper() + DUO_REST[1:]), DUO_ACT[a][:1] + (DUO_ACT[a][1][0].upper() + DUO_ACT[a][1][1:],),
                                      (1, DUO_REST[0].upper() + DUO_REST[1:]), DUO_ACT[b][:1] + (DUO_ACT[b][1][0].upper() + DUO_ACT[b][1][1:],),
                                      (1, DUO_REST[0].upper() + DUO_REST[1:])], intro)


CHAINS = {
    "walk": chain("walk", ["idle", "turn_to_side", "walk", "turn_to_front"], [
        (1.5, "The character " + REST),
        (1, "The character turns 90 degrees in place to profile, facing right"),
        (4, "The character walks to the right in place, as if on a treadmill: four steady strides, arms swinging "
            "opposite to the legs, the body staying at the same spot in the frame"),
        (1, "The character stops and turns back to face the viewer"),
        (1, "The character " + REST)]),
    "lie": chain("lie", ["lie_down", "lie_idle", "get_up"], [
        (1, "The character " + REST),
        (2, "The character kneels down and lies on the stomach, head on the right and feet on the left, propped on "
            "the elbows with the chin resting in both hands, lower legs bent up in the air"),
        (3, "The character stays lying there, smiling at the viewer and lazily swinging the lower legs back and forth; "
            "the body does not move from its spot"),
        (2, "The character pushes up onto the knees, then rises fully onto both feet and stands upright facing "
            "the viewer"),
        (1, "The character " + REST)]),
    "lie_phone": chain("lie_mid", ["lie_phone"], [
        (1, "The character " + REST),
        (2, "The character kneels down and lies on the stomach, head on the right and feet on the left, propped on "
            "the elbows, lower legs bent up in the air"),
        (3, "The character takes out a smartphone, looks at it with both hands, giggles at the screen while the legs "
            "kick slowly, then puts it away and rests the chin in both hands"),
        (2, "The character pushes up onto the knees, then rises fully onto both feet and stands upright facing "
            "the viewer"),
        (1, "The character " + REST)]),
    "actions_a": actions("wave", "bow"),
    "actions_b": actions("jump", "spin"),
}
OPTIONAL = {
    "actions_c": actions("cheer", "stretch"),
    "actions_d": actions("dance", "wave"),
}
DUO_CHAINS = {
    "duo_a": duo("bump", "high_five"),
    "duo_b": duo("tickle", "pillow_fight"),
}
