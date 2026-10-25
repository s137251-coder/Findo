"""Turns raw phone captures into the store page's captioned screenshots.

    python tool/caption_screenshots.py

Reads `store/screenshots/raw/<language>/`, writes `store/screenshots/<language>/`,
which is the folder `tool/update_listing.py` uploads from.

A bare capture shows a screen; a store screenshot has to say what the screen is
for, in one line, to somebody scrolling past at speed. So each one gets a
headline and a line under it, on the game's own colours, with the capture set
underneath like a phone. 1080x1920 is the size Play shows largest and the one
it asks for before a game can be featured.

The type is Rubik, an open font that carries Hebrew and Latin in one design, so
the two listings look like the same game. Its licence is next to it in
tool/fonts.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store/screenshots/raw"
OUT = ROOT / "store/screenshots"
FONT = ROOT / "tool/fonts/Rubik.ttf"

SIZE = (1080, 1920)
TOP = (0x1B, 0x22, 0x36)
BOTTOM = (0x0E, 0x11, 0x1A)
AMBER = (0xFF, 0xC5, 0x3D)
WHITE = (0xF5, 0xF7, 0xFA)

# Order is the order on the store page: the hunt itself first, because the
# first screenshot is the one most people see and nothing else explains the
# game as quickly.
SHOTS = {
    "en": [
        ("3-hunt", "Spot her in the crowd",
         "Hundreds of people. One girl. Find her before time runs out."),
        ("2-levels", "100 levels to search",
         "Bigger crowds, look-alikes and a tighter clock"),
        ("4-hint", "Stuck? Use a hint",
         "The map pans to Findo and makes her glow"),
        ("6-daily", "A new Daily Hunt every day",
         "One try. Every player. One leaderboard."),
        ("5-win", "Earn up to 3 stars",
         "Find her fast for a big time bonus"),
        ("1-title", "One girl. A hundred crowds.",
         "Free to play, in English and Hebrew"),
    ],
    "he": [
        ("3-hunt", "מצאו אותה בתוך הקהל",
         "מאות אנשים. ילדה אחת. מצאו אותה לפני שהזמן נגמר."),
        ("2-levels", "100 שלבים מאתגרים",
         "קהל גדול יותר, כפילות ושעון קצר יותר"),
        ("4-hint", "נתקעתם? קחו רמז",
         "המפה זזה לכיוון פינדו והיא זוהרת"),
        ("6-daily", "חיפוש יומי חדש כל יום",
         "ניסיון אחד. כל השחקנים. טבלת שיאים אחת."),
        ("7-leaderboard", "התחרו בכל השחקנים",
         "טבלה יומית, שבועית ושל כל הזמנים"),
        ("5-win", "עד 3 כוכבים בכל שלב",
         "מצאו אותה מהר וקבלו בונוס זמן גדול"),
        ("1-title", "ילדה אחת. מאה המונים.",
         "חינם, בעברית ובאנגלית"),
    ],
}


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(FONT), size)
    face.set_variation_by_name(weight)
    return face


def background() -> Image.Image:
    """The game's dark blue, falling to near black, with a warm glow behind
    the phone so it lifts off the page."""
    width, height = SIZE
    image = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        draw.line([(0, y), (width, y)],
                  fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    glow = Image.new("L", SIZE, 0)
    ImageDraw.Draw(glow).ellipse((90, 620, width - 90, 1860), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    image.paste(Image.new("RGB", SIZE, AMBER), (0, 0), glow)
    return image


def wrap(draw: ImageDraw.ImageDraw, text: str, face, width: int,
         direction: str) -> list[str]:
    """Breaks [text] into lines no wider than [width]."""
    lines: list[str] = []
    for word in text.split():
        trial = f"{lines[-1]} {word}" if lines else word
        if lines and draw.textlength(trial, font=face, direction=direction) <= width:
            lines[-1] = trial
        elif not lines:
            lines.append(word)
        else:
            lines.append(word)
    return lines


def centred(draw: ImageDraw.ImageDraw, lines: list[str], face, top: int,
            colour, direction: str, leading: float) -> int:
    for line in lines:
        width = draw.textlength(line, font=face, direction=direction)
        draw.text(((SIZE[0] - width) / 2, top), line, font=face, fill=colour,
                  direction=direction)
        top += round(face.size * leading)
    return top


def phone(capture: Image.Image, height: int) -> tuple[Image.Image, Image.Image]:
    """The capture with rounded corners inside a thin bezel, and its shadow."""
    width = round(capture.width * height / capture.height)
    screen = capture.convert("RGB").resize((width, height), Image.LANCZOS)
    bezel = 14
    radius = 56
    frame = Image.new("RGB", (width + bezel * 2, height + bezel * 2), (0x05, 0x07, 0x10))
    mask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *frame.size), radius=radius, fill=255)
    inner = Image.new("L", screen.size, 0)
    ImageDraw.Draw(inner).rounded_rectangle((0, 0, *screen.size), radius=radius - bezel,
                                            fill=255)
    frame.paste(screen, (bezel, bezel), inner)
    shadow = Image.new("L", (frame.width + 120, frame.height + 120), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((60, 80, 60 + frame.width, 80 + frame.height),
                                             radius=radius, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    framed = Image.new("RGBA", frame.size)
    framed.paste(frame, (0, 0), mask)
    return framed, shadow


def compose(capture: Image.Image, headline: str, subline: str, rtl: bool) -> Image.Image:
    direction = "rtl" if rtl else "ltr"
    image = background()
    draw = ImageDraw.Draw(image)
    big = font(84, "Bold")
    small = font(42, "Medium")
    margin = 80
    lines = wrap(draw, headline, big, SIZE[0] - margin * 2, direction)
    top = centred(draw, lines, big, 110, WHITE, direction, 1.18)
    top = centred(draw, wrap(draw, subline, small, SIZE[0] - margin * 2, direction),
                  small, top + 18, AMBER, direction, 1.3)

    phone_top = max(top + 50, 470)
    framed, shadow = phone(capture, SIZE[1] - phone_top - 40)
    left = (SIZE[0] - framed.width) // 2
    image.paste((0, 0, 0), (left - 60, phone_top - 60), shadow)
    image.paste(framed, (left, phone_top), framed)
    return image


def main() -> None:
    for language, shots in SHOTS.items():
        folder = OUT / language
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("*.png"):
            old.unlink()
        for number, (name, headline, subline) in enumerate(shots, start=1):
            capture = Image.open(RAW / language / f"{name}.png")
            out = folder / f"{number}-{name.split('-', 1)[1]}.png"
            compose(capture, headline, subline, rtl=language == "he").save(out, optimize=True)
            print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
