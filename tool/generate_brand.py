"""Generates Findo's launcher icons and Google Play store graphics.

    python tool/generate_brand.py

Writes, all from one vector-ish definition so every size stays on-brand:

  android/app/src/main/res/mipmap-*/ic_launcher.png          legacy launcher
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive layer
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml    adaptive icon
  android/app/src/main/res/values/ic_launcher_background.xml    adaptive colour
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png           iOS app icon
  store/icon-512.png                                            Play listing icon
  store/feature-graphic-1024x500.png                            Play feature graphic

The mark is a magnifying glass over scattered shapes: the same idea as the
game, readable down to 48px.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ICONS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
STORE = ROOT / "store"
MAPS = ROOT / "assets" / "images" / "maps"
TARGET_SPRITE = ROOT / "assets" / "images" / "targets" / "findo.png"
CUSTOM_ART = ROOT / "store" / "feature-art.png"

# The funfair crop that becomes the feature graphic, and where Findo stands in it.
SCENE_BOX = (300, 300, 2048, 1154)
FEATURE_W, FEATURE_H = 1024, 500
FINDO_X, FINDO_FEET_Y, FINDO_H = 164, 245, 46

NAVY = (20, 24, 36)
NAVY_LIGHT = (30, 37, 56)
AMBER = (255, 197, 61)
AMBER_DEEP = (214, 158, 30)
GLASS = (168, 214, 240)

CONFETTI = [
    (232, 96, 88), (96, 160, 220), (132, 190, 96),
    (240, 140, 190), (250, 178, 78), (140, 120, 220),
]

# Density buckets: legacy launcher px, adaptive foreground px (108dp square).
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def supersample(size: int, draw_fn, factor: int = 4) -> Image.Image:
    """Draws at N times the size and scales down, so edges come out smooth."""
    big = Image.new("RGBA", (size * factor, size * factor), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(big), size * factor)
    return big.resize((size, size), Image.LANCZOS)


def draw_confetti(d: ImageDraw.ImageDraw, s: float, cx: float, cy: float, spread: float):
    """A ring of little shapes, the things the player is hunting for."""
    shapes = [
        (0.00, "circle"), (0.16, "square"), (0.33, "triangle"),
        (0.50, "circle"), (0.66, "square"), (0.83, "triangle"),
    ]
    for i, (t, kind) in enumerate(shapes):
        angle = 2 * math.pi * t - math.pi / 2
        r = spread * (0.72 if i % 2 else 1.0)
        x = cx + math.cos(angle) * r
        y = cy + math.sin(angle) * r
        size = s * (0.052 if i % 2 else 0.062)
        color = CONFETTI[i % len(CONFETTI)]
        if kind == "circle":
            d.ellipse([x - size, y - size, x + size, y + size], fill=color)
        elif kind == "square":
            d.rounded_rectangle(
                [x - size, y - size, x + size, y + size],
                radius=size * 0.32, fill=color,
            )
        else:
            d.polygon(
                [(x, y - size), (x + size, y + size * 0.85), (x - size, y + size * 0.85)],
                fill=color,
            )


def draw_mark(d: ImageDraw.ImageDraw, s: float, scale: float = 1.0, cx=None, cy=None):
    """The magnifying glass itself, centred on (cx, cy) in a canvas of size s."""
    cx = s * 0.46 if cx is None else cx
    cy = s * 0.44 if cy is None else cy
    lens_r = s * 0.235 * scale
    ring = s * 0.062 * scale

    # Glass, then the shapes seen through it, then the ring on top.
    d.ellipse([cx - lens_r, cy - lens_r, cx + lens_r, cy + lens_r], fill=GLASS)
    inner = lens_r - ring * 0.5
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=(226, 240, 250))
    draw_confetti(d, s * scale, cx, cy, lens_r * 0.52)

    d.ellipse(
        [cx - lens_r, cy - lens_r, cx + lens_r, cy + lens_r],
        outline=AMBER, width=int(ring),
    )

    # Handle, drawn as a thick rounded bar at 45 degrees.
    hx = cx + lens_r * 0.70
    hy = cy + lens_r * 0.70
    tx = cx + lens_r * 1.72
    ty = cy + lens_r * 1.72
    d.line([(hx, hy), (tx, ty)], fill=AMBER_DEEP, width=int(ring * 1.45))
    cap = ring * 0.72
    d.ellipse([tx - cap, ty - cap, tx + cap, ty + cap], fill=AMBER_DEEP)

    # A highlight sweep across the glass sells the "lens" read.
    d.arc(
        [cx - lens_r * 0.62, cy - lens_r * 0.62, cx + lens_r * 0.62, cy + lens_r * 0.62],
        200, 290, fill=(255, 255, 255), width=max(1, int(ring * 0.42)),
    )


def rounded_background(d: ImageDraw.ImageDraw, s: float, radius_ratio: float):
    d.rounded_rectangle([0, 0, s, s], radius=s * radius_ratio, fill=NAVY)
    # A soft warm glow behind the mark, so the icon is not flat black.
    glow = s * 0.42
    d.ellipse(
        [s * 0.46 - glow, s * 0.44 - glow, s * 0.46 + glow, s * 0.44 + glow],
        fill=NAVY_LIGHT,
    )


def legacy_icon(size: int) -> Image.Image:
    def paint(d, s):
        rounded_background(d, s, 0.22)
        draw_mark(d, s)
    return supersample(size, paint)


def square_icon(size: int) -> Image.Image:
    """No rounded corners: iOS applies its own mask."""
    def paint(d, s):
        d.rectangle([0, 0, s, s], fill=NAVY)
        glow = s * 0.42
        d.ellipse([s * 0.46 - glow, s * 0.44 - glow, s * 0.46 + glow, s * 0.44 + glow],
                  fill=NAVY_LIGHT)
        draw_mark(d, s)
    return supersample(size, paint)


def adaptive_foreground(size: int) -> Image.Image:
    """Adaptive icons crop to the middle ~66%, so the mark is drawn smaller."""
    def paint(d, s):
        draw_mark(d, s, scale=0.72, cx=s * 0.5, cy=s * 0.48)
    return supersample(size, paint)


def store_icon() -> Image.Image:
    """Play wants 512x512, 32-bit, and no transparency."""
    icon = legacy_icon(512).convert("RGBA")
    flat = Image.new("RGB", (512, 512), NAVY)
    flat.paste(icon, (0, 0), icon)
    return flat


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in (
        ROOT / "assets" / "fonts" / "Findo-Bold.ttf",
        ROOT / "assets" / "fonts" / "Findo-Regular.ttf",
    ):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default(size)


def scene_band() -> Image.Image:
    """The banner's backdrop: a crop of real level art, not an abstract pattern.

    Level 3, the funfair, is the scene that reads at a glance -- a ferris wheel
    and a carousel say "game", and the crowd around them says what kind.

    Drop a purpose-drawn crowd at `store/feature-art.png` and that is used
    instead, centre-cropped to the banner. See docs/GEMINI_FEATURE_GRAPHIC.md --
    the art is a crowd and nothing else; Findo, the lens and the wordmark are
    composited here so she stays on-model and the type stays crisp.
    """
    if CUSTOM_ART.exists():
        src = Image.open(CUSTOM_ART).convert("RGB")
        scale = max(FEATURE_W / src.width, FEATURE_H / src.height)
        src = src.resize(
            (max(FEATURE_W, round(src.width * scale)),
             max(FEATURE_H, round(src.height * scale))), Image.LANCZOS,
        )
        left = (src.width - FEATURE_W) // 2
        top = (src.height - FEATURE_H) // 2
        return src.crop((left, top, left + FEATURE_W, top + FEATURE_H))

    src = Image.open(MAPS / "level_03.webp").convert("RGB")
    return src.crop(SCENE_BOX).resize((FEATURE_W, FEATURE_H), Image.LANCZOS)


def best_findo_spot(band: Image.Image, radius: int) -> tuple[int, int]:
    """Finds where to stand her: a clear gap with people pressed up against it.

    Only used for custom art, where the hand-picked coordinates below do not
    apply. Scores a clear footprint, dense immediate neighbours, and a lens that
    fits inside the frame -- a gap in open ground scores badly on purpose,
    because a magnifier over empty sand says nothing about the game.
    """
    edges = band.convert("L").filter(ImageFilter.FIND_EDGES)

    def density(x0, y0, x1, y1):
        box = (max(0, x0), max(0, y0), min(FEATURE_W, x1), min(FEATURE_H, y1))
        if box[2] <= box[0] or box[3] <= box[1]:
            return 0.0
        return ImageStat.Stat(edges.crop(box)).mean[0]

    best = (-1e9, FINDO_X, FINDO_FEET_Y)
    for x in range(60, FEATURE_W - 60, 4):
        for feet in range(FINDO_H + 40, FEATURE_H - 40, 4):
            cy = feet - FINDO_H // 2
            if cy - radius < 22 or cy + radius > FEATURE_H - 22 or x - radius < 22:
                continue
            if x + radius > int(FEATURE_W * 0.40):  # keep clear of the wordmark
                continue
            her = density(x - 13, feet - FINDO_H - 6, x + 13, feet + 4)
            if her > 1.5:
                continue
            near = density(x - 58, cy - 58, x + 58, cy + 58)
            lens = density(x - radius, cy - radius, x + radius, cy + radius)
            score = near * 2 + lens - her * 10
            if score > best[0]:
                best = (score, x, feet)
    return best[1], best[2]


def place_findo(base: Image.Image, cx: int, feet_y: int, height: int) -> None:
    """Drops Findo into the crowd at crowd scale, standing on the ground."""
    sprite = Image.open(TARGET_SPRITE).convert("RGBA")
    w = max(1, round(sprite.width * height / sprite.height))
    sprite = sprite.resize((w, height), Image.LANCZOS)
    base.paste(sprite, (round(cx - w / 2), feet_y - height), sprite)


def draw_lens(base: Image.Image, cx: int, cy: int, r: int, zoom: float) -> None:
    """A magnifier over the art, showing the crowd magnified inside the glass.

    This is the whole game in one image: she is in the scene at crowd scale,
    and the glass is what makes her findable.
    """
    side = max(2, round(2 * r / zoom))
    half = side // 2
    box = (cx - half, cy - half, cx - half + side, cy - half + side)
    patch = base.crop(box).resize((2 * r, 2 * r), Image.LANCZOS)

    mask = Image.new("L", (2 * r, 2 * r), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)

    ring = max(6, round(r * 0.10))
    d = ImageDraw.Draw(base)

    # Handle first, so the ring caps it cleanly.
    hx, hy = cx + r * 0.70, cy + r * 0.70
    tx, ty = cx + r * 1.62, cy + r * 1.62
    d.line([(hx, hy), (tx, ty)], fill=AMBER_DEEP, width=round(ring * 1.5))
    cap = ring * 0.75
    d.ellipse([tx - cap, ty - cap, tx + cap, ty + cap], fill=AMBER_DEEP)

    # A dark rim under the glass lifts it off busy art.
    d.ellipse(
        [cx - r - ring * 0.55, cy - r - ring * 0.55, cx + r + ring * 0.55, cy + r + ring * 0.55],
        outline=(24, 28, 40), width=max(2, round(ring * 0.32)),
    )
    base.paste(patch, (cx - r, cy - r), mask)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=AMBER, width=ring)
    d.arc(
        [cx - r * 0.66, cy - r * 0.66, cx + r * 0.66, cy + r * 0.66],
        200, 288, fill=(255, 255, 255), width=max(2, round(ring * 0.45)),
    )


def side_scrim(width: int, height: int, start: float) -> Image.Image:
    """A gradient panel so the wordmark reads over illustration."""
    scrim = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = scrim.load()
    for x in range(width):
        t = (x / width - start) / (1 - start)
        a = 0 if t <= 0 else round(234 * min(1.0, t) ** 0.70)
        if a:
            for y in range(height):
                px[x, y] = (*NAVY, a)
    return scrim


def feature_graphic(spot: tuple[int, int] | None = None) -> Image.Image:
    """1024x500, no transparency, and safe to have text cropped at the edges."""
    img = scene_band()
    radius = 118

    # She stands in the crowd on the left, at the same scale as everyone else.
    if spot is not None:
        x, feet = spot
        cy = feet - FINDO_H // 2 - 3
        if min(x, cy) - radius < 0 or cy + radius > FEATURE_H or x + radius > FEATURE_W:
            print(f"warning: the lens around {x},{feet} runs off the banner; "
                  f"keep x in {radius}..{FEATURE_W - radius} and feet_y in "
                  f"{radius + FINDO_H // 2 + 3}..{FEATURE_H - radius + FINDO_H // 2 + 3}")
    elif CUSTOM_ART.exists():
        x, feet = best_findo_spot(img, radius)
    else:
        x, feet = FINDO_X, FINDO_FEET_Y
    place_findo(img, x, feet, FINDO_H)
    draw_lens(img, x, feet - FINDO_H // 2 - 3, radius, 1.95)

    img = img.convert("RGBA")
    img.alpha_composite(side_scrim(FEATURE_W, FEATURE_H, 0.40))
    img = img.convert("RGB")

    d = ImageDraw.Draw(img)
    title_font = load_font(108)
    tag_font = load_font(31)
    right = FEATURE_W - 68
    d.text((right, 262), "Findo", font=title_font, fill=(247, 249, 252), anchor="rs")
    d.text((right, 312), "One girl. Hundreds of faces.", font=tag_font,
           fill=AMBER, anchor="rs")
    return img


def parse_spot(value: str | None) -> tuple[int, int] | None:
    if not value:
        return None
    try:
        x, feet = (int(part) for part in value.split(","))
    except ValueError:
        raise SystemExit("--findo takes two integers, as X,FEET_Y") from None
    return x, feet


def main(spot: tuple[int, int] | None = None) -> None:
    STORE.mkdir(exist_ok=True)

    for density, (legacy_px, fg_px) in DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy_icon(legacy_px).save(folder / "ic_launcher.png")
        adaptive_foreground(fg_px).save(folder / "ic_launcher_foreground.png")
    print(f"android launcher icons: {len(DENSITIES)} densities")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    values = RES / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#141824</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print("adaptive icon: written")

    if IOS_ICONS.exists():
        contents = json.loads((IOS_ICONS / "Contents.json").read_text(encoding="utf-8"))
        written = 0
        for entry in contents.get("images", []):
            filename = entry.get("filename")
            if not filename:
                continue
            base = float(entry["size"].split("x")[0])
            scale = float(entry.get("scale", "1x").rstrip("x"))
            px = int(round(base * scale))
            square_icon(px).convert("RGB").save(IOS_ICONS / filename)
            written += 1
        print(f"ios app icons: {written}")

    store_icon().save(STORE / "icon-512.png")
    feature_graphic(spot).save(STORE / "feature-graphic-1024x500.png")
    print("store graphics: icon-512.png, feature-graphic-1024x500.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--findo", metavar="X,FEET_Y",
        help="where Findo stands in the feature graphic, in 1024x500 banner "
             "pixels, FEET_Y being the ground under her shoes. Overrides the "
             "automatic search used for store/feature-art.png.",
    )
    main(parse_spot(parser.parse_args().findo))
