"""Generates Findo's shipped art and audio.

Every asset the game loads is produced here, so the pipeline is reproducible:

    python tool/generate_assets.py

Replace the output with hand-authored art and music when it is ready; the file
names and the level JSON contract are what the game depends on, not this script.
"""

from __future__ import annotations

import json
import math
import random
import struct
import wave
from array import array
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets" / "images"
AUDIO = ROOT / "assets" / "audio"
LEVELS = ROOT / "assets" / "levels"

WORLD_W, WORLD_H = 2048, 1536
ITEM_PX = 128
SAMPLE_RATE = 22050


# --------------------------------------------------------------------------
# drawing helpers
# --------------------------------------------------------------------------

def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        px[0, y] = mix(top, bottom, y / max(1, h - 1))
    return img.resize((w, h), Image.BILINEAR)


def blob(draw, cx, cy, rx, ry, color, seed, wobble=0.18, points=22):
    rnd = random.Random(seed)
    pts = []
    for i in range(points):
        a = 2 * math.pi * i / points
        r = 1.0 + rnd.uniform(-wobble, wobble)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    draw.polygon(pts, fill=color)


def tree(draw, x, y, scale, leaf, trunk, seed):
    rnd = random.Random(seed)
    tw = int(16 * scale)
    draw.rectangle([x - tw // 2, y - int(90 * scale), x + tw // 2, y], fill=trunk)
    for i in range(4):
        cx = x + rnd.randint(-int(30 * scale), int(30 * scale))
        cy = y - int(rnd.randint(90, 150) * scale)
        r = int(rnd.randint(40, 62) * scale)
        shade = mix(leaf, (0, 0, 0), 0.12 * (i % 2))
        draw.ellipse([cx - r, cy - r, cx + r, cy + int(r * 0.9)], fill=shade)


def bush(draw, x, y, scale, color, seed):
    rnd = random.Random(seed)
    for i in range(3):
        r = int(rnd.randint(26, 40) * scale)
        cx = x + rnd.randint(-int(24 * scale), int(24 * scale))
        draw.ellipse([cx - r, y - r, cx + r, y + int(r * 0.6)], fill=mix(color, (0, 0, 0), 0.08 * i))


def cloud(draw, x, y, scale, color):
    for dx, dy, r in ((0, 0, 46), (44, 8, 34), (-42, 10, 30), (18, -16, 30)):
        draw.ellipse(
            [x + (dx - r) * scale, y + (dy - r) * scale, x + (dx + r) * scale, y + (dy + r) * scale],
            fill=color,
        )


def clutter(draw, rnd, palette, count, bounds):
    """Small decorations that resemble the collectables, so searching is real work."""
    x0, y0, x1, y1 = bounds
    for _ in range(count):
        x = rnd.randint(x0, x1)
        y = rnd.randint(y0, y1)
        r = rnd.randint(9, 26)
        color = rnd.choice(palette)
        shape = rnd.randint(0, 3)
        if shape == 0:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=color)
        elif shape == 1:
            draw.rounded_rectangle([x - r, y - r, x + r, y + r], radius=r // 3, fill=color)
        elif shape == 2:
            draw.polygon([(x, y - r), (x + r, y + r), (x - r, y + r)], fill=color)
        else:
            draw.rounded_rectangle([x - r, y - r // 2, x + r, y + r // 2], radius=r // 3, fill=color)


# --------------------------------------------------------------------------
# scenes
# --------------------------------------------------------------------------

def scene_park() -> Image.Image:
    rnd = random.Random(11)
    img = vertical_gradient((WORLD_W, WORLD_H), (150, 205, 245), (206, 235, 250))
    d = ImageDraw.Draw(img)
    for i in range(7):
        cloud(d, rnd.randint(80, WORLD_W - 80), rnd.randint(70, 300), rnd.uniform(0.7, 1.4), (255, 255, 255))
    d.rectangle([0, 560, WORLD_W, WORLD_H], fill=(122, 178, 92))
    blob(d, 1450, 1080, 420, 210, (86, 160, 196), 3, wobble=0.10)
    blob(d, 1450, 1080, 396, 190, (108, 186, 216), 4, wobble=0.10)
    d.polygon([(0, 900), (WORLD_W, 700), (WORLD_W, 800), (0, 1010)], fill=(214, 194, 160))
    d.polygon([(340, WORLD_H), (520, 620), (600, 620), (560, WORLD_H)], fill=(214, 194, 160))
    for i in range(9):
        tree(d, rnd.randint(60, WORLD_W - 60), rnd.randint(600, 780), rnd.uniform(0.8, 1.5),
             (58, 132, 74), (108, 78, 52), 100 + i)
    for i in range(16):
        bush(d, rnd.randint(40, WORLD_W - 40), rnd.randint(820, 1480), rnd.uniform(0.7, 1.3),
             (74, 148, 86), 200 + i)
    for bx, by in ((260, 1180), (980, 940), (1720, 1320)):
        d.rounded_rectangle([bx - 90, by - 18, bx + 90, by + 6], radius=8, fill=(160, 106, 62))
        d.rounded_rectangle([bx - 90, by - 74, bx + 90, by - 52], radius=8, fill=(178, 120, 72))
        d.rectangle([bx - 78, by + 6, bx - 62, by + 52], fill=(120, 84, 52))
        d.rectangle([bx + 62, by + 6, bx + 78, by + 52], fill=(120, 84, 52))
    clutter(d, rnd, [(232, 96, 88), (240, 190, 74), (96, 150, 220), (238, 140, 190),
                     (140, 210, 130), (250, 170, 90)], 190, (40, 600, WORLD_W - 40, WORLD_H - 40))
    return img


def scene_market() -> Image.Image:
    rnd = random.Random(23)
    img = vertical_gradient((WORLD_W, WORLD_H), (250, 216, 168), (246, 232, 206))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 640, WORLD_W, WORLD_H], fill=(198, 176, 152))
    for x in range(0, WORLD_W, 128):
        d.line([(x, 640), (x, WORLD_H)], fill=(186, 164, 140), width=4)
    for y in range(680, WORLD_H, 96):
        d.line([(0, y), (WORLD_W, y)], fill=(186, 164, 140), width=4)
    stall_colors = [(214, 82, 76), (74, 138, 196), (240, 176, 66), (108, 168, 108), (170, 108, 186)]
    for i, sx in enumerate(range(120, WORLD_W - 120, 400)):
        c = stall_colors[i % len(stall_colors)]
        d.rectangle([sx - 150, 470, sx + 150, 520], fill=mix(c, (0, 0, 0), 0.2))
        for k in range(6):
            x0 = sx - 150 + k * 50
            d.polygon([(x0, 520), (x0 + 50, 520), (x0 + 25, 570)],
                      fill=c if k % 2 == 0 else (250, 244, 232))
        d.rectangle([sx - 140, 570, sx - 128, 900], fill=(122, 90, 62))
        d.rectangle([sx + 128, 570, sx + 140, 900], fill=(122, 90, 62))
        d.rounded_rectangle([sx - 160, 860, sx + 160, 900], radius=10, fill=(150, 110, 74))
        for k in range(14):
            r = rnd.randint(12, 24)
            cx = rnd.randint(sx - 130, sx + 130)
            cy = rnd.randint(790, 850)
            d.ellipse([cx - r, cy - r, cx + r, cy + r],
                      fill=rnd.choice([(228, 92, 76), (244, 188, 70), (132, 190, 96), (216, 128, 190)]))
    for i in range(10):
        bx = rnd.randint(80, WORLD_W - 80)
        by = rnd.randint(1000, 1440)
        w, h = rnd.randint(70, 130), rnd.randint(60, 100)
        d.rounded_rectangle([bx - w, by - h, bx + w, by + h], radius=12, fill=(184, 140, 96))
        d.line([(bx - w, by), (bx + w, by)], fill=(160, 118, 78), width=6)
    clutter(d, rnd, [(228, 92, 76), (244, 188, 70), (132, 190, 96), (216, 128, 190),
                     (96, 160, 220), (250, 150, 90)], 210, (40, 660, WORLD_W - 40, WORLD_H - 40))
    return img


def scene_beach() -> Image.Image:
    rnd = random.Random(37)
    img = vertical_gradient((WORLD_W, WORLD_H), (128, 196, 240), (176, 224, 248))
    d = ImageDraw.Draw(img)
    d.ellipse([1700, 90, 1900, 290], fill=(255, 236, 160))
    d.rectangle([0, 520, WORLD_W, 900], fill=(64, 150, 190))
    for y in range(540, 900, 40):
        t = (y - 540) / 360
        d.line([(0, y), (WORLD_W, y)], fill=mix((64, 150, 190), (150, 214, 232), t), width=14)
    d.polygon([(0, 900), (WORLD_W, 850), (WORLD_W, WORLD_H), (0, WORLD_H)], fill=(240, 220, 172))
    blob(d, 300, 1120, 260, 90, (246, 230, 186), 5, wobble=0.08)
    blob(d, 1500, 1330, 300, 100, (246, 230, 186), 6, wobble=0.08)
    for px, ph in ((240, 1.0), (1180, 0.85), (1860, 1.1)):
        base_y = int(1180 * ph)
        d.rectangle([px - 12, base_y - int(320 * ph), px + 12, base_y], fill=(140, 100, 62))
        for a in (-1.0, -0.5, 0.0, 0.5, 1.0):
            ex = px + int(math.cos(a) * 150 * ph)
            ey = base_y - int(320 * ph) - int(math.sin(abs(a)) * 40 * ph)
            d.polygon([(px, base_y - int(320 * ph)), (ex, ey - 40), (ex + 20, ey + 20)],
                      fill=(56, 138, 84))
    for i in range(6):
        ux, uy = rnd.randint(150, WORLD_W - 150), rnd.randint(1000, 1440)
        r = rnd.randint(70, 110)
        col = rnd.choice([(232, 96, 88), (250, 190, 70), (96, 160, 220), (240, 140, 190)])
        for k in range(6):
            a0, a1 = 180 + k * 30, 180 + (k + 1) * 30
            d.pieslice([ux - r, uy - r, ux + r, uy + r], a0, a1,
                       fill=col if k % 2 == 0 else (252, 248, 240))
        d.line([(ux, uy), (ux + 40, uy + 90)], fill=(150, 110, 70), width=8)
    clutter(d, rnd, [(232, 96, 88), (250, 190, 70), (96, 160, 220), (240, 140, 190),
                     (255, 255, 255), (150, 214, 232)], 200, (40, 920, WORLD_W - 40, WORLD_H - 40))
    return img


# --------------------------------------------------------------------------
# collectable sprites
# --------------------------------------------------------------------------

OUTLINE = (38, 32, 46, 255)


def new_sprite():
    img = Image.new("RGBA", (ITEM_PX, ITEM_PX), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def item_apple():
    img, d = new_sprite()
    d.ellipse([18, 34, 110, 118], fill=(214, 62, 58, 255), outline=OUTLINE, width=4)
    d.ellipse([50, 30, 78, 50], fill=(214, 62, 58, 255))
    d.line([(64, 40), (64, 16)], fill=(102, 66, 40, 255), width=7)
    d.polygon([(66, 24), (100, 8), (92, 34)], fill=(88, 162, 84, 255), outline=OUTLINE)
    d.ellipse([38, 54, 58, 74], fill=(244, 150, 146, 200))
    return img


def item_key():
    img, d = new_sprite()
    d.ellipse([12, 30, 68, 86], fill=(238, 190, 62, 255), outline=OUTLINE, width=4)
    d.ellipse([28, 46, 52, 70], fill=(0, 0, 0, 0))
    d.ellipse([28, 46, 52, 70], outline=OUTLINE, width=4)
    d.rounded_rectangle([60, 48, 118, 68], radius=6, fill=(238, 190, 62, 255), outline=OUTLINE, width=4)
    d.rectangle([92, 66, 104, 90], fill=(238, 190, 62, 255), outline=OUTLINE, width=4)
    return img


def item_hat():
    img, d = new_sprite()
    d.ellipse([8, 78, 120, 114], fill=(70, 108, 178, 255), outline=OUTLINE, width=4)
    d.rounded_rectangle([34, 20, 94, 88], radius=14, fill=(84, 128, 200, 255), outline=OUTLINE, width=4)
    d.rectangle([30, 68, 98, 84], fill=(226, 84, 92, 255), outline=OUTLINE, width=3)
    return img


def item_book():
    img, d = new_sprite()
    d.polygon([(16, 30), (64, 44), (64, 108), (16, 94)], fill=(196, 74, 70, 255), outline=OUTLINE)
    d.polygon([(112, 30), (64, 44), (64, 108), (112, 94)], fill=(224, 106, 96, 255), outline=OUTLINE)
    for i in range(3):
        y = 58 + i * 14
        d.line([(26, y), (58, y + 4)], fill=(252, 244, 236, 255), width=4)
        d.line([(70, y + 4), (102, y)], fill=(252, 244, 236, 255), width=4)
    return img


def item_umbrella():
    img, d = new_sprite()
    for k in range(4):
        a0, a1 = 180 + k * 45, 180 + (k + 1) * 45
        d.pieslice([14, 18, 114, 118], a0, a1,
                   fill=(226, 84, 92, 255) if k % 2 == 0 else (250, 246, 238, 255), outline=OUTLINE)
    d.line([(64, 68), (64, 108)], fill=(102, 74, 52, 255), width=8)
    d.arc([46, 96, 82, 122], 0, 180, fill=(102, 74, 52, 255), width=8)
    return img


def item_ball():
    img, d = new_sprite()
    d.ellipse([16, 16, 112, 112], fill=(250, 248, 244, 255), outline=OUTLINE, width=4)
    d.polygon([(64, 34), (86, 52), (78, 78), (50, 78), (42, 52)], fill=(46, 44, 58, 255))
    for a in range(0, 360, 72):
        r = math.radians(a)
        d.line([(64 + math.cos(r) * 26, 64 + math.sin(r) * 26),
                (64 + math.cos(r) * 48, 64 + math.sin(r) * 48)], fill=(46, 44, 58, 255), width=5)
    return img


def item_cat():
    img, d = new_sprite()
    d.ellipse([26, 44, 102, 116], fill=(246, 166, 76, 255), outline=OUTLINE, width=4)
    d.polygon([(30, 56), (36, 18), (62, 44)], fill=(246, 166, 76, 255), outline=OUTLINE)
    d.polygon([(98, 56), (92, 18), (66, 44)], fill=(246, 166, 76, 255), outline=OUTLINE)
    d.ellipse([46, 66, 58, 84], fill=(46, 44, 58, 255))
    d.ellipse([70, 66, 82, 84], fill=(46, 44, 58, 255))
    d.polygon([(58, 90), (70, 90), (64, 98)], fill=(214, 96, 120, 255))
    for sx in (26, 84):
        for dy in (-6, 4):
            d.line([(sx, 88 + dy), (sx - 18 if sx == 26 else sx + 18, 84 + dy)], fill=OUTLINE, width=3)
    return img


def item_glasses():
    img, d = new_sprite()
    d.ellipse([12, 44, 58, 90], outline=(58, 62, 92, 255), width=8)
    d.ellipse([70, 44, 116, 90], outline=(58, 62, 92, 255), width=8)
    d.line([(58, 62), (70, 62)], fill=(58, 62, 92, 255), width=8)
    d.line([(12, 60), (0, 50)], fill=(58, 62, 92, 255), width=7)
    d.line([(116, 60), (128, 50)], fill=(58, 62, 92, 255), width=7)
    return img


def item_fish():
    img, d = new_sprite()
    d.ellipse([20, 42, 100, 96], fill=(92, 176, 216, 255), outline=OUTLINE, width=4)
    d.polygon([(96, 68), (124, 42), (124, 94)], fill=(70, 150, 196, 255), outline=OUTLINE)
    d.ellipse([36, 58, 50, 72], fill=(250, 250, 250, 255), outline=OUTLINE, width=2)
    d.ellipse([40, 62, 47, 69], fill=(38, 32, 46, 255))
    d.arc([44, 56, 88, 90], 200, 340, fill=(70, 150, 196, 255), width=5)
    return img


def item_star():
    img, d = new_sprite()
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 54 if i % 2 == 0 else 24
        pts.append((64 + math.cos(a) * r, 64 + math.sin(a) * r))
    d.polygon(pts, fill=(250, 202, 62, 255), outline=OUTLINE)
    return img


def item_boot():
    img, d = new_sprite()
    d.polygon([(38, 18), (76, 18), (78, 78), (114, 88), (114, 112), (34, 112), (34, 60)],
              fill=(126, 84, 56, 255), outline=OUTLINE)
    d.rectangle([34, 96, 114, 112], fill=(74, 62, 56, 255), outline=OUTLINE, width=3)
    for y in (34, 50, 66):
        d.line([(42, y), (72, y)], fill=(88, 58, 40, 255), width=4)
    return img


def item_cup():
    img, d = new_sprite()
    d.polygon([(28, 40), (96, 40), (86, 106), (38, 106)], fill=(250, 248, 244, 255), outline=OUTLINE)
    d.arc([84, 48, 118, 86], 300, 120, fill=OUTLINE, width=7)
    d.ellipse([28, 30, 96, 52], fill=(122, 82, 58, 255), outline=OUTLINE, width=4)
    return img


ITEM_BUILDERS = {
    "apple": item_apple,
    "key": item_key,
    "hat": item_hat,
    "book": item_book,
    "umbrella": item_umbrella,
    "ball": item_ball,
    "cat": item_cat,
    "glasses": item_glasses,
    "fish": item_fish,
    "star": item_star,
    "boot": item_boot,
    "cup": item_cup,
}


# --------------------------------------------------------------------------
# audio
# --------------------------------------------------------------------------

def write_wav(path: Path, samples: list[float]) -> None:
    frames = array("h")
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = 0.86 / peak
    for s in samples:
        frames.append(int(max(-1.0, min(1.0, s * scale)) * 32767))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames.tobytes())


def envelope(i: int, n: int, attack: float, release: float) -> float:
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq: float, seconds: float, *, gain=1.0, attack=0.02, release=0.35,
         harmonics=(1.0, 0.32, 0.12), vibrato=0.0, detune=0.0) -> list[float]:
    n = int(SAMPLE_RATE * seconds)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 + detune * t)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t)
        v = 0.0
        for k, amp in enumerate(harmonics, start=1):
            v += amp * math.sin(2 * math.pi * f * k * t)
        out.append(v * envelope(i, n, attack, release) * gain)
    return out


def noise_hit(seconds: float, cutoff: float, gain=1.0) -> list[float]:
    rnd = random.Random(7)
    n = int(SAMPLE_RATE * seconds)
    out, prev = [], 0.0
    alpha = cutoff / (cutoff + SAMPLE_RATE)
    for i in range(n):
        prev = prev + alpha * (rnd.uniform(-1, 1) - prev)
        out.append(prev * envelope(i, n, 0.01, 0.7) * gain)
    return out


def overlay(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def sequence(parts: list[tuple[float, list[float]]]) -> list[float]:
    """parts: (start_seconds, samples)."""
    total = max(int(start * SAMPLE_RATE) + len(buf) for start, buf in parts)
    out = [0.0] * total
    for start, buf in parts:
        off = int(start * SAMPLE_RATE)
        for i, v in enumerate(buf):
            out[off + i] += v
    return out


NOTE = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
        "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
        "G5": 783.99, "A5": 880.00, "C6": 1046.50, "A3": 220.00, "F3": 174.61,
        "G3": 196.00, "C3": 130.81}


def sfx_click() -> list[float]:
    return overlay(tone(880, 0.07, attack=0.01, release=0.8, harmonics=(1.0, 0.2)),
                   noise_hit(0.05, 4000, gain=0.25))


def sfx_found() -> list[float]:
    return sequence([(0.0, tone(NOTE["E5"], 0.16, harmonics=(1.0, 0.25, 0.1))),
                     (0.09, tone(NOTE["A5"], 0.26, gain=0.9))])


def sfx_misclick() -> list[float]:
    return overlay(tone(150, 0.26, harmonics=(1.0, 0.5, 0.35), detune=-0.28, release=0.5),
                   noise_hit(0.18, 900, gain=0.35))


def sfx_combo() -> list[float]:
    return sequence([(0.00, tone(NOTE["C5"], 0.13, gain=0.8)),
                     (0.07, tone(NOTE["E5"], 0.13, gain=0.8)),
                     (0.14, tone(NOTE["G5"], 0.15, gain=0.85)),
                     (0.21, tone(NOTE["C6"], 0.30, gain=0.9))])


def sfx_hint() -> list[float]:
    return overlay(tone(NOTE["C6"], 0.55, gain=0.5, attack=0.15, release=0.6, vibrato=0.012),
                   tone(NOTE["G5"], 0.55, gain=0.32, attack=0.2, release=0.6))


def sfx_win() -> list[float]:
    parts = []
    for i, note in enumerate(("C5", "E5", "G5", "C6")):
        parts.append((i * 0.13, tone(NOTE[note], 0.42, gain=0.75)))
    parts.append((0.52, tone(NOTE["C5"], 0.9, gain=0.45)))
    parts.append((0.52, tone(NOTE["E5"], 0.9, gain=0.38)))
    parts.append((0.52, tone(NOTE["G5"], 0.9, gain=0.34)))
    return sequence(parts)


def bgm_loop() -> list[float]:
    """A calm 16 second loop: four bars of pad plus a wandering lead."""
    bar = 4.0
    chords = [("C3", ("C4", "E4", "G4")), ("A3", ("A4", "C5", "E5")),
              ("F3", ("F4", "A4", "C5")), ("G3", ("G4", "B4", "D5"))]
    lead = [("E5", 0.0, 0.9), ("G5", 1.0, 0.7), ("C5", 2.0, 1.2), ("D5", 3.2, 0.6),
            ("A4", 4.2, 1.0), ("C5", 5.4, 0.8), ("E5", 6.4, 1.3),
            ("F4", 8.2, 1.0), ("A4", 9.4, 0.8), ("C5", 10.4, 1.2),
            ("D5", 12.2, 0.9), ("B4", 13.4, 0.7), ("G4", 14.4, 1.4)]
    parts = []
    for b, (bass, triad) in enumerate(chords):
        t0 = b * bar
        parts.append((t0, tone(NOTE[bass], bar * 0.98, gain=0.30, attack=0.12,
                               release=0.35, harmonics=(1.0, 0.18))))
        for note in triad:
            parts.append((t0 + 0.04, tone(NOTE[note], bar * 0.9, gain=0.13, attack=0.25,
                                          release=0.45, harmonics=(1.0, 0.1))))
    for note, at, dur in lead:
        parts.append((at, tone(NOTE[note], dur, gain=0.24, attack=0.08, release=0.5,
                               harmonics=(1.0, 0.22, 0.06))))
    return sequence(parts)


AUDIO_BUILDERS = {
    "click": sfx_click,
    "found": sfx_found,
    "misclick": sfx_misclick,
    "combo": sfx_combo,
    "hint": sfx_hint,
    "win": sfx_win,
    "bgm_main": bgm_loop,
}


# --------------------------------------------------------------------------
# levels
# --------------------------------------------------------------------------

LEVEL_PLANS = [
    {
        "id": "level_01", "index": 1, "nameKey": "level.park", "scene": "park",
        "builder": scene_park, "time": 150, "stars": (700, 1200, 1700),
        "region": (140, 640, WORLD_W - 140, WORLD_H - 140),
        "items": ["apple", "key", "hat", "ball", "cat", "book"],
    },
    {
        "id": "level_02", "index": 2, "nameKey": "level.market", "scene": "market",
        "builder": scene_market, "time": 150, "stars": (900, 1500, 2100),
        "region": (140, 700, WORLD_W - 140, WORLD_H - 140),
        "items": ["cup", "glasses", "umbrella", "boot", "star", "apple", "key"],
    },
    {
        "id": "level_03", "index": 3, "nameKey": "level.beach", "scene": "beach",
        "builder": scene_beach, "time": 160, "stars": (1100, 1800, 2500),
        "region": (140, 940, WORLD_W - 140, WORLD_H - 140),
        "items": ["fish", "star", "ball", "boot", "glasses", "cup", "hat", "cat"],
    },
]


def place_items(item_ids, region, seed):
    """Scatters collectables without letting two of them overlap."""
    rnd = random.Random(seed)
    x0, y0, x1, y1 = region
    placed = []
    for item_id in item_ids:
        size = rnd.randint(92, 124)
        for _ in range(600):
            x = rnd.randint(x0, x1)
            y = rnd.randint(y0, y1)
            if all(math.dist((x, y), (p["x"], p["y"])) > 230 for p in placed):
                break
        placed.append({
            "id": item_id,
            "sprite": f"items/{item_id}.png",
            "x": x,
            "y": y,
            "size": size,
            "angle": round(rnd.uniform(-0.35, 0.35), 3),
        })
    return placed


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def main() -> None:
    for folder in (IMAGES / "levels", IMAGES / "items", AUDIO, LEVELS):
        folder.mkdir(parents=True, exist_ok=True)

    for name, builder in ITEM_BUILDERS.items():
        sprite = builder()
        sprite.save(IMAGES / "items" / f"{name}.png")
    print(f"sprites: {len(ITEM_BUILDERS)}")

    for plan in LEVEL_PLANS:
        scene = plan["builder"]().convert("RGB")
        scene = scene.filter(ImageFilter.SMOOTH)
        scene.save(IMAGES / "levels" / f"{plan['scene']}.png", optimize=True)

        level = {
            "id": plan["id"],
            "index": plan["index"],
            "nameKey": plan["nameKey"],
            "background": f"levels/{plan['scene']}.png",
            "worldSize": {"width": WORLD_W, "height": WORLD_H},
            "timeLimitSeconds": plan["time"],
            "starThresholds": {
                "one": plan["stars"][0],
                "two": plan["stars"][1],
                "three": plan["stars"][2],
            },
            "items": place_items(plan["items"], plan["region"], seed=plan["index"] * 991),
        }
        (LEVELS / f"{plan['id']}.json").write_text(
            json.dumps(level, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"level: {plan['id']} ({len(level['items'])} items)")

    manifest = {"levels": [plan["id"] for plan in LEVEL_PLANS]}
    (LEVELS / "index.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    for name, builder in AUDIO_BUILDERS.items():
        write_wav(AUDIO / f"{name}.wav", builder())
    print(f"audio: {len(AUDIO_BUILDERS)}")


if __name__ == "__main__":
    main()
