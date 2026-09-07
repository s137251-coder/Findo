"""Draws the cartoon figures Findo's maps are populated with.

One routine draws every person in the game, Findo included. That is the whole
point: the character the player is hunting for is built from the same parts as
the crowd around them, so finding her is a real search rather than spotting the
one thing that looks different.
"""

from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw

INK = (26, 22, 30, 255)

SKINS = [
    (247, 214, 184), (232, 190, 154), (203, 154, 112),
    (166, 118, 78), (122, 82, 54), (86, 58, 40),
]

HAIRS = [
    (58, 42, 34), (26, 22, 24), (128, 84, 44),
    (196, 148, 74), (172, 78, 52), (150, 150, 158),
]

CLOTHES = [
    (214, 62, 58), (232, 122, 54), (246, 190, 62), (120, 178, 78),
    (58, 148, 130), (62, 122, 200), (108, 82, 176), (198, 88, 152),
    (240, 240, 244), (74, 78, 96), (168, 106, 62), (92, 176, 208),
]

# Findo's own colours, from the character sheet: brown braids, a yellow top
# with a black yoke, and a purple skirt.
FINDO = {
    "skin": (246, 206, 176),
    "hair": (120, 74, 40),
    "top": (250, 206, 62),
    "yoke": (32, 28, 34),
    "skirt": (146, 62, 168),
    "shoes": (32, 28, 34),
    "braids": True,
    "skirt_shape": True,
}


def _outline(d, xy, fill, width=2, shape="ellipse"):
    if shape == "ellipse":
        d.ellipse(xy, fill=fill, outline=INK, width=width)
    else:
        d.rectangle(xy, fill=fill, outline=INK, width=width)


def draw_person(
    d: ImageDraw.ImageDraw,
    x: float,
    y: float,
    height: float,
    look: dict,
    line: int = 2,
):
    """Draws one figure standing with its feet at (x, y).

    [look] carries skin, hair, top, skirt (or trousers), shoes, and the two
    flags that make Findo herself: braids and an A-line skirt.
    """
    h = height
    skin = look["skin"]
    hair = look["hair"]
    top = look["top"]
    lower = look["skirt"]
    shoes = look["shoes"]
    braids = look.get("braids", False)
    skirt_shape = look.get("skirt_shape", False)

    head_r = h * 0.115
    head_cy = y - h + head_r * 1.15
    shoulder_y = head_cy + head_r * 1.35
    waist_y = y - h * 0.46
    hem_y = y - h * 0.30
    body_w = h * 0.20

    # Legs first, so the skirt and top overlap them.
    leg_w = h * 0.055
    for side in (-1, 1):
        lx = x + side * h * 0.055
        d.rounded_rectangle(
            [lx - leg_w / 2, hem_y - h * 0.02, lx + leg_w / 2, y - h * 0.035],
            radius=leg_w / 2, fill=skin, outline=INK, width=line,
        )
    for side in (-1, 1):
        sx = x + side * h * 0.06
        d.rounded_rectangle(
            [sx - leg_w * 0.85, y - h * 0.05, sx + leg_w * 0.85, y],
            radius=leg_w * 0.5, fill=shoes, outline=INK, width=line,
        )

    # Lower half: an A-line skirt, or plain trousers.
    if skirt_shape:
        d.polygon(
            [
                (x - body_w * 0.52, waist_y),
                (x + body_w * 0.52, waist_y),
                (x + body_w * 0.92, hem_y),
                (x - body_w * 0.92, hem_y),
            ],
            fill=lower, outline=INK,
        )
    else:
        d.rounded_rectangle(
            [x - body_w * 0.55, waist_y, x + body_w * 0.55, hem_y + h * 0.04],
            radius=body_w * 0.2, fill=lower, outline=INK, width=line,
        )

    # Torso.
    d.rounded_rectangle(
        [x - body_w * 0.55, shoulder_y, x + body_w * 0.55, waist_y + h * 0.01],
        radius=body_w * 0.28, fill=top, outline=INK, width=line,
    )
    if "yoke" in look:
        d.polygon(
            [
                (x - body_w * 0.5, shoulder_y + h * 0.012),
                (x + body_w * 0.5, shoulder_y + h * 0.012),
                (x, shoulder_y + h * 0.115),
            ],
            fill=look["yoke"],
        )

    # Arms.
    arm_w = h * 0.048
    for side in (-1, 1):
        ax = x + side * (body_w * 0.60)
        d.rounded_rectangle(
            [ax - arm_w / 2, shoulder_y + h * 0.01, ax + arm_w / 2, waist_y + h * 0.03],
            radius=arm_w / 2, fill=skin, outline=INK, width=line,
        )

    # Head, hair, then braids on top of everything.
    _outline(d, [x - head_r, head_cy - head_r, x + head_r, head_cy + head_r], skin, line)
    d.chord(
        [x - head_r, head_cy - head_r, x + head_r, head_cy + head_r],
        180, 360, fill=hair, outline=INK, width=line,
    )
    if braids:
        braid_w = head_r * 0.46
        for side in (-1, 1):
            bx = x + side * head_r * 1.02
            d.rounded_rectangle(
                [bx - braid_w, head_cy - head_r * 0.35,
                 bx + braid_w, head_cy + head_r * 1.55],
                radius=braid_w, fill=hair, outline=INK, width=line,
            )
    eye_r = max(1.0, head_r * 0.13)
    for side in (-1, 1):
        ex = x + side * head_r * 0.36
        d.ellipse([ex - eye_r, head_cy - eye_r, ex + eye_r, head_cy + eye_r], fill=INK)


def random_look(rnd: random.Random) -> dict:
    """A crowd member. Never Findo's exact combination."""
    while True:
        look = {
            "skin": rnd.choice(SKINS),
            "hair": rnd.choice(HAIRS),
            "top": rnd.choice(CLOTHES),
            "skirt": rnd.choice(CLOTHES),
            "shoes": rnd.choice([(40, 36, 44), (72, 48, 36), (30, 30, 34), (200, 200, 206)]),
            "braids": rnd.random() < 0.22,
            "skirt_shape": rnd.random() < 0.42,
        }
        same_as_findo = (
            look["top"] == FINDO["top"]
            and look["skirt"] == FINDO["skirt"]
            and look["braids"]
        )
        if not same_as_findo:
            return look


def render_findo(height: int = 220, pad: int = 12) -> Image.Image:
    """Findo on her own, transparent, for the map and the HUD alike."""
    w = int(height * 0.60) + pad * 2
    h = height + pad * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_person(d, w / 2, h - pad, height, FINDO, line=max(2, height // 70))
    return img.crop(img.getbbox())


def crowd_positions(rnd: random.Random, count: int, bounds, min_gap: float):
    """Scatters standing positions without stacking figures on top of each other."""
    x0, y0, x1, y1 = bounds
    placed = []
    attempts = 0
    while len(placed) < count and attempts < count * 60:
        attempts += 1
        p = (rnd.uniform(x0, x1), rnd.uniform(y0, y1))
        if all(math.dist(p, q) > min_gap for q in placed):
            placed.append(p)
    return placed
