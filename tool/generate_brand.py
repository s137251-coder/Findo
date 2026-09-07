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

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ICONS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
STORE = ROOT / "store"

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


def feature_graphic() -> Image.Image:
    """1024x500, no transparency, and safe to have text cropped at the edges."""
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), NAVY)
    d = ImageDraw.Draw(img)

    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(
            int(NAVY[i] + (NAVY_LIGHT[i] - NAVY[i]) * t) for i in range(3)
        ))

    # Scattered shapes across the whole banner, denser away from the text.
    rnd = __import__("random").Random(4)
    for _ in range(120):
        x = rnd.randint(0, w)
        y = rnd.randint(0, h)
        if 250 < x < 780 and 170 < y < 330:
            continue
        r = rnd.randint(4, 13)
        c = CONFETTI[rnd.randrange(len(CONFETTI))]
        faded = tuple(int(NAVY[i] + (c[i] - NAVY[i]) * rnd.uniform(0.25, 0.75)) for i in range(3))
        kind = rnd.randint(0, 2)
        if kind == 0:
            d.ellipse([x - r, y - r, x + r, y + r], fill=faded)
        elif kind == 1:
            d.rounded_rectangle([x - r, y - r, x + r, y + r], radius=r // 3, fill=faded)
        else:
            d.polygon([(x, y - r), (x + r, y + r), (x - r, y + r)], fill=faded)

    mark = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    draw_mark(ImageDraw.Draw(mark), 300, scale=0.95, cx=150, cy=140)
    mark = mark.resize((300, 300), Image.LANCZOS)
    img.paste(mark, (150, 100), mark)

    title_font = load_font(112)
    tag_font = load_font(38)
    d.text((500, 190), "Findo", font=title_font, fill=(245, 247, 250))
    d.text((506, 312), "Find every hidden thing", font=tag_font, fill=(165, 174, 194))
    return img


def main() -> None:
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
    feature_graphic().save(STORE / "feature-graphic-1024x500.png")
    print("store graphics: icon-512.png, feature-graphic-1024x500.png")


if __name__ == "__main__":
    main()
