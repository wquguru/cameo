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
TAIL = ("Static camera, locked-off shot, no zoom, no pan. Full body visible, feet always in frame. "
        "Keep the plain solid chroma-key background of the input image: one flat color, evenly lit, "
        "no shadows, no gradient, no floor. Keep the exact art style, colors and design of the input image.")
NEG = ("camera movement, zoom, pan, cut, scene change, background objects, floor, floor shadow, gradient background, "
       "checkerboard, transparency grid, white background, green spill, cropped feet, extra limbs, "
       "deformed hands, morphing clothes, color change, text, watermark, blurry, child, loli, underage")

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
REST = "stands still facing the viewer in the starting pose, breathing softly"
DUO_REST = "both stand still side by side facing the viewer, breathing softly"


def prompt(beats, intro):
    """Intro sentence + a timed beat list; the times also tell cut_clips.py where to look."""
    t, lines = 0.0, []
    for sec, text in beats:
        lines.append(f"{t:g}–{t + sec:g} s: {text}.")
        t += sec
    return f"{intro} {t:g} seconds, one continuous shot.\n" + "\n".join(lines), t


def chain(mode, cuts, beats, intro="A single character, full body, on a plain solid-color background."):
    text, sec = prompt(beats, intro)
    return dict(mode=mode, cuts=cuts, seconds=sec, prompt=text, beats=beats)


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
        (2, "The character pushes up, kneels and stands up facing the viewer"),
        (1, "The character " + REST)]),
    "lie_phone": chain("lie_mid", ["lie_phone"], [
        (1, "The character " + REST),
        (2, "The character kneels down and lies on the stomach, head on the right and feet on the left, propped on "
            "the elbows, lower legs bent up in the air"),
        (3, "The character takes out a smartphone, looks at it with both hands, giggles at the screen while the legs "
            "kick slowly, then puts it away and rests the chin in both hands"),
        (2, "The character pushes up, kneels and stands up facing the viewer"),
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
