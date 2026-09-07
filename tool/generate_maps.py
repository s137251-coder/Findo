"""Generates Findo's character sprite and the crowded maps she hides in.

    python tool/generate_maps.py

Writes:
  assets/images/targets/findo.png        the character, on her own
  assets/images/maps/level_0N.png        2048x2048 crowded scenes
  assets/images/maps/meta/level_0N.json  where Findo is in each one

The scenes are programmer art. They are built from the same figure routine as
Findo herself, so the hunt is genuine, but they are meant to be replaced with
hand-drawn illustration. To swap one in, drop the image into
`assets/images/maps/` and register it with `tool/level_data.py` -- nothing in
the Dart code changes.
"""

from __future__ import annotations

import random

from PIL import Image, ImageDraw

from draw_people import (
    FINDO,
    INK,
    crowd_positions,
    draw_person,
    random_look,
    render_findo,
)
from level_data import ROOT, write_level

MAPS = ROOT / "assets" / "images" / "maps"
TARGETS = ROOT / "assets" / "images" / "targets"

SIZE = 2048
SUPERSAMPLE = 2
S = SIZE * SUPERSAMPLE

# Findo stands a little taller than the crowd: findable, not obvious.
CROWD_HEIGHT = (78, 104)
FINDO_HEIGHT = 118


def band(d, y0, y1, colour):
    d.rectangle([0, y0, S, y1], fill=colour)


def building(d, x, y, w, h, wall, roof, seed):
    rnd = random.Random(seed)
    d.rectangle([x, y - h, x + w, y], fill=wall, outline=INK, width=5)
    d.polygon([(x - w * 0.06, y - h), (x + w * 1.06, y - h),
               (x + w * 0.82, y - h - h * 0.22), (x + w * 0.18, y - h - h * 0.22)],
              fill=roof, outline=INK)
    cols = max(2, int(w // (S * 0.035)))
    rows = max(2, int(h // (S * 0.055)))
    for r in range(rows):
        for c in range(cols):
            wx = x + w * (c + 0.5) / cols
            wy = y - h + h * (r + 0.45) / rows
            ww, wh = w / cols * 0.44, h / rows * 0.46
            lit = rnd.random() < 0.35
            d.rectangle([wx - ww / 2, wy - wh / 2, wx + ww / 2, wy + wh / 2],
                        fill=(250, 236, 180) if lit else (176, 208, 226),
                        outline=INK, width=4)
    d.rectangle([x + w * 0.42, y - h * 0.28, x + w * 0.58, y],
                fill=(126, 78, 52), outline=INK, width=5)


def tree(d, x, y, r, seed):
    rnd = random.Random(seed)
    d.rectangle([x - r * 0.16, y - r * 1.1, x + r * 0.16, y], fill=(122, 82, 52), outline=INK, width=4)
    for i in range(5):
        a = 2 * 3.14159 * i / 5
        cx = x + r * 0.55 * (0 if i == 0 else (1 if i % 2 else -1)) * rnd.uniform(0.4, 1.0)
        cy = y - r * 1.35 + rnd.uniform(-r * 0.25, r * 0.25)
        rr = r * rnd.uniform(0.55, 0.8)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                  fill=(96, 168, 74) if i % 2 else (76, 148, 62), outline=INK, width=4)


def add_crowd(d, rnd, bounds, count, min_gap):
    for (x, y) in crowd_positions(rnd, count, bounds, min_gap):
        draw_person(d, x, y, rnd.uniform(*CROWD_HEIGHT) * SUPERSAMPLE,
                    random_look(rnd), line=4)


# --------------------------------------------------------------------------
# scenes
# --------------------------------------------------------------------------

def scene_town(d, rnd):
    band(d, 0, S * 0.30, (188, 196, 204))
    band(d, S * 0.30, S, (150, 176, 96))
    d.polygon([(0, S * 0.34), (S, S * 0.30), (S, S * 0.44), (0, S * 0.48)], fill=(176, 176, 182))
    for i in range(7):
        x = S * (0.02 + i * 0.14)
        d.rectangle([x, S * 0.33, x + S * 0.055, S * 0.45], fill=(248, 248, 250))
    for i, (bx, bw, bh, wall, roof) in enumerate([
        (0.00, 0.20, 0.30, (92, 150, 118), (54, 96, 78)),
        (0.22, 0.24, 0.34, (206, 96, 92), (150, 60, 58)),
        (0.50, 0.20, 0.28, (150, 130, 196), (98, 84, 142)),
        (0.73, 0.26, 0.33, (226, 176, 96), (168, 122, 60)),
    ]):
        building(d, S * bx, S * 0.34, S * bw, S * bh, wall, roof, 30 + i)
    # Fountain in the middle of the plaza.
    cx, cy = S * 0.46, S * 0.62
    d.ellipse([cx - S * 0.13, cy - S * 0.07, cx + S * 0.13, cy + S * 0.07],
              fill=(178, 176, 182), outline=INK, width=6)
    d.ellipse([cx - S * 0.10, cy - S * 0.05, cx + S * 0.10, cy + S * 0.05],
              fill=(148, 206, 232), outline=INK, width=5)
    for i in range(9):
        a = 3.14159 * i / 8
        d.line([(cx, cy - S * 0.02),
                (cx + S * 0.075 * (i / 8 - 0.5) * 2, cy - S * 0.055)],
               fill=(226, 244, 252), width=7)
    for i in range(14):
        tree(d, rnd.uniform(S * 0.02, S * 0.98), rnd.uniform(S * 0.5, S * 0.98),
             S * rnd.uniform(0.035, 0.055), 70 + i)
    for i in range(6):
        bx, by = rnd.uniform(S * 0.05, S * 0.9), rnd.uniform(S * 0.55, S * 0.95)
        d.rounded_rectangle([bx, by, bx + S * 0.09, by + S * 0.012], radius=8,
                            fill=(150, 100, 60), outline=INK, width=4)
    add_crowd(d, rnd, (S * 0.02, S * 0.36, S * 0.98, S * 0.97), 240, S * 0.030)


def scene_farm(d, rnd):
    band(d, 0, S * 0.22, (168, 206, 226))
    band(d, S * 0.22, S, (238, 226, 152))
    d.polygon([(0, S * 0.22), (S, S * 0.22), (S, S * 0.40), (0, S * 0.36)], fill=(140, 190, 96))
    for i, (bx, bw, bh) in enumerate([(0.60, 0.24, 0.20), (0.06, 0.18, 0.15)]):
        building(d, S * bx, S * 0.44, S * bw, S * bh, (168, 92, 62), (120, 60, 44), 90 + i)
    d.rectangle([S * 0.44, S * 0.16, S * 0.50, S * 0.42], fill=(226, 228, 232), outline=INK, width=6)
    for i in range(9):
        y = S * (0.18 + i * 0.026)
        d.line([(S * 0.44, y), (S * 0.50, y)], fill=INK, width=4)
    for i in range(4):
        hx, hy = S * (0.22 + i * 0.05), S * 0.50
        d.polygon([(hx, hy), (hx + S * 0.075, hy), (hx + S * 0.037, hy - S * 0.11)],
                  fill=(222, 196, 116), outline=INK)
    for fy in (0.62, 0.80, 0.94):
        d.line([(0, S * fy), (S, S * fy)], fill=(150, 108, 68), width=7)
        for i in range(26):
            px = S * i / 26
            d.line([(px, S * fy - S * 0.03), (px, S * fy + S * 0.01)], fill=(150, 108, 68), width=6)
    for i in range(30):
        sx, sy = rnd.uniform(S * 0.03, S * 0.97), rnd.uniform(S * 0.44, S * 0.97)
        r = S * 0.016
        d.ellipse([sx - r * 1.4, sy - r, sx + r * 1.4, sy + r], fill=(250, 250, 248), outline=INK, width=4)
        d.ellipse([sx + r * 1.1, sy - r * 0.7, sx + r * 2.1, sy + r * 0.3], fill=(60, 56, 60), outline=INK, width=4)
    for i in range(12):
        tree(d, rnd.uniform(S * 0.02, S * 0.98), rnd.uniform(S * 0.30, S * 0.46),
             S * rnd.uniform(0.030, 0.045), 130 + i)
    add_crowd(d, rnd, (S * 0.02, S * 0.30, S * 0.98, S * 0.97), 210, S * 0.032)


def scene_fair(d, rnd):
    band(d, 0, S * 0.26, (126, 170, 214))
    band(d, S * 0.26, S, (196, 176, 140))
    for i in range(6):
        sx = S * (0.03 + i * 0.165)
        colour = [(214, 74, 70), (74, 138, 196), (240, 176, 66),
                  (108, 168, 108), (170, 108, 186), (232, 128, 84)][i]
        d.rectangle([sx, S * 0.30, sx + S * 0.135, S * 0.44], fill=(232, 224, 210), outline=INK, width=5)
        for k in range(6):
            x0 = sx + k * S * 0.0225
            d.polygon([(x0, S * 0.30), (x0 + S * 0.0225, S * 0.30), (x0 + S * 0.011, S * 0.265)],
                      fill=colour if k % 2 == 0 else (250, 246, 238), outline=INK)
        d.rectangle([sx, S * 0.44, sx + S * 0.135, S * 0.46], fill=(140, 100, 66), outline=INK, width=4)
    # Big wheel.
    cx, cy, r = S * 0.78, S * 0.56, S * 0.19
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=10)
    for i in range(12):
        a = 6.28318 * i / 12
        import math
        ex, ey = cx + math.cos(a) * r, cy + math.sin(a) * r
        d.line([(cx, cy), (ex, ey)], fill=(120, 116, 128), width=7)
        d.rounded_rectangle([ex - S * 0.018, ey - S * 0.014, ex + S * 0.018, ey + S * 0.020],
                            radius=10, fill=[(232, 96, 88), (250, 190, 70), (96, 160, 220)][i % 3],
                            outline=INK, width=5)
    for i in range(11):
        tree(d, rnd.uniform(S * 0.02, S * 0.55), rnd.uniform(S * 0.60, S * 0.98),
             S * rnd.uniform(0.030, 0.048), 170 + i)
    for i in range(40):
        bx, by = rnd.uniform(S * 0.02, S * 0.98), rnd.uniform(S * 0.30, S * 0.98)
        r = S * rnd.uniform(0.008, 0.014)
        d.ellipse([bx - r, by - r, bx + r, by + r],
                  fill=rnd.choice([(232, 96, 88), (250, 190, 70), (96, 160, 220), (240, 140, 190)]),
                  outline=INK, width=4)
        d.line([(bx, by + r), (bx + r * 0.4, by + r * 4)], fill=INK, width=3)
    add_crowd(d, rnd, (S * 0.02, S * 0.34, S * 0.98, S * 0.97), 250, S * 0.030)


def star_thresholds(time_limit: int) -> tuple[int, int, int]:
    """Score is 100 + 10 per second left on the clock, so the ceiling is
    100 + time_limit * 10 and it is only reached by finding her instantly.
    These cuts ask for the level to be cleared inside roughly the first 28%,
    55% and 90% of the time allowed."""
    ceiling = time_limit * 10
    return (
        round(100 + ceiling * 0.10),
        round(100 + ceiling * 0.45),
        round(100 + ceiling * 0.72),
    )


LEVELS = [
    {"id": "level_01", "index": 1, "nameKey": "level.town", "scene": scene_town,
     "seed": 11, "time": 120, "spot": (0.30, 0.86)},
    {"id": "level_02", "index": 2, "nameKey": "level.farm", "scene": scene_farm,
     "seed": 23, "time": 120, "spot": (0.72, 0.70)},
    {"id": "level_03", "index": 3, "nameKey": "level.fair", "scene": scene_fair,
     "seed": 37, "time": 130, "spot": (0.44, 0.92)},
]


def main() -> None:
    MAPS.mkdir(parents=True, exist_ok=True)
    TARGETS.mkdir(parents=True, exist_ok=True)

    findo = render_findo(height=440)
    findo.save(TARGETS / "findo.png")
    print(f"target sprite: findo.png {findo.size[0]}x{findo.size[1]}")

    for plan in LEVELS:
        rnd = random.Random(plan["seed"])
        canvas = Image.new("RGB", (S, S), (255, 255, 255))
        d = ImageDraw.Draw(canvas)
        plan["scene"](d, rnd)

        # Findo goes on last so no crowd member covers her.
        height = int(FINDO_HEIGHT * SUPERSAMPLE)
        sprite = findo.resize(
            (max(1, int(findo.width * height / findo.height)), height), Image.LANCZOS
        )
        fx = int(S * plan["spot"][0] - sprite.width / 2)
        fy = int(S * plan["spot"][1] - sprite.height)
        canvas.paste(sprite, (fx, fy), sprite)

        final = canvas.resize((SIZE, SIZE), Image.LANCZOS)
        map_name = f"{plan['id']}.png"
        final.save(MAPS / map_name, optimize=True)

        write_level(
            level_id=plan["id"],
            index=plan["index"],
            name_key=plan["nameKey"],
            map_rel=f"maps/{map_name}",
            map_size=(SIZE, SIZE),
            target=(
                fx // SUPERSAMPLE,
                fy // SUPERSAMPLE,
                sprite.width // SUPERSAMPLE,
                sprite.height // SUPERSAMPLE,
            ),
            time_limit=plan["time"],
            stars=star_thresholds(plan["time"]),
        )
        print(f"{plan['id']}: {SIZE}x{SIZE}, Findo at "
              f"({fx // SUPERSAMPLE}, {fy // SUPERSAMPLE}) "
              f"{sprite.width // SUPERSAMPLE}x{sprite.height // SUPERSAMPLE}")


if __name__ == "__main__":
    main()
