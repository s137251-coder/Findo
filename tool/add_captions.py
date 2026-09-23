"""Puts Hebrew captions and the game's own music onto a finished clip.

Burning either in costs something: the platforms give more reach to captions
written in their own editor and to sounds taken from their own library. This
is here because a ready-made file is sometimes worth more than that -- it can
be posted by somebody who is not going to fiddle with a caption tool, and it
can be sent to somebody for approval.

    python tool/add_captions.py --clip store/clips/story_clip.mp4

The music comes from the game's own soundtrack, which is already licensed for
the game and already sounds like it.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MUSIC = ROOT / "assets/audio/music"
FONT = Path(r"C:/Windows/Fonts/arialbd.ttf")

# The game's own colours, so the clip and the app look like one thing.
INK = (20, 24, 36)
PAPER = (255, 255, 255)
ACCENT = (250, 204, 21)

# Where a caption sits, as a fraction of the frame height.
#
# High, normally: the bottom third of a phone screen belongs to the app -- the
# caption, the buttons, the handle -- and a word put there is a word covered.
# But the opening shot is her face, and the first version of this dropped a
# black plate straight across it, which undoes the one thing that shot is for.
# So each line carries its own height.
HIGH = 0.17
LOW = 0.66


def hebrew(text: str) -> str:
    """Hebrew reads right to left; a drawing library does not know that."""
    return get_display(text)


def fit(draw: ImageDraw.ImageDraw, text: str, width: int, size: int) -> ImageFont.FreeTypeFont:
    """The largest size that still fits the line inside the frame."""
    while size > 24:
        font = ImageFont.truetype(str(FONT), size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 4
    return ImageFont.truetype(str(FONT), size)


def caption(image: Image.Image, text: str, alpha: float, accent: bool,
            where: float) -> Image.Image:
    """One line of words on a dark rounded plate, so it reads over a crowd."""
    if alpha <= 0.01 or not text:
        return image
    out = image.convert("RGBA")
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    shaped = hebrew(text)
    margin = int(out.width * 0.08)
    font = fit(draw, shaped, out.width - margin * 2, int(out.width * 0.115))
    w = draw.textlength(shaped, font=font)
    h = font.size
    x = (out.width - w) / 2
    y = out.height * where

    pad_x, pad_y = h * 0.55, h * 0.42
    plate = (x - pad_x, y - pad_y, x + w + pad_x, y + h * 1.32 + pad_y)
    draw.rounded_rectangle(plate, radius=int(h * 0.42),
                           fill=(*INK, int(215 * alpha)))
    draw.text((x, y), shaped, font=font,
              fill=(*(ACCENT if accent else PAPER), int(255 * alpha)))

    out.alpha_composite(layer)
    return out.convert("RGB")


def show(lines, t: float):
    """Which line is on screen at [t], how faded, and where it sits."""
    for start, end, text, accent, where in lines:
        if start <= t <= end:
            fade = 0.28
            alpha = min(1.0, (t - start) / fade, (end - t) / fade)
            return text, max(0.0, alpha), accent, where
    return "", 0.0, False, HIGH


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clip", default="store/clips/story_clip.mp4")
    # Measured rather than chosen by its name: 129 beats a minute and the
    # strongest pulse of the six tracks the game ships with.
    parser.add_argument("--music", default="mixkit-lovin-life-1107.mp3")
    parser.add_argument("--volume", type=float, default=0.55)
    parser.add_argument("--out", default="story_clip_captioned.mp4")
    args = parser.parse_args()

    clip = Path(args.clip)
    reader = imageio_ffmpeg.read_frames(str(clip), output_params=["-vsync", "0"])
    meta = reader.__next__()
    width, height = meta["size"]
    fps = meta["fps"]

    # A joke in five beats: hello, goodbye, good luck, and the punchline on
    # its own line. Saying it straight -- "she hides in the crowd, can you
    # find her" -- describes the clip the viewer is already watching, which is
    # the one thing a caption should never do.
    #
    # No emoji: the font that draws Hebrew here has none, and a missing glyph
    # is an empty box in the middle of the joke.
    lines = [
        # Low, under her face, which is what this shot is for.
        (0.4, 2.4, "זאת פינדו. תגידו שלום.", False, LOW),
        (2.9, 5.4, "עכשיו תגידו ביי", False, HIGH),
        (6.5, 9.2, "מוצאים אותה? בהצלחה", True, HIGH),
        (9.6, 10.9, "יש עוד 99 שלבים כאלה", False, HIGH),
        (11.0, 99.0, "סליחה", True, HIGH),
    ]

    silent = clip.with_name("_silent.mp4")
    writer = imageio_ffmpeg.write_frames(
        str(silent), (width, height), fps=fps, quality=8,
        macro_block_size=8, ffmpeg_log_level="error",
    )
    writer.send(None)
    frames = 0
    for raw in reader:
        image = Image.frombytes("RGB", (width, height), raw)
        text, alpha, accent, where = show(lines, frames / fps)
        writer.send(caption(image, text, alpha, accent, where).tobytes())
        frames += 1
    writer.close()

    seconds = frames / fps
    track = MUSIC / args.music
    out = clip.with_name(args.out)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run([
        ffmpeg, "-y", "-i", str(silent), "-stream_loop", "-1", "-i", str(track),
        "-filter_complex",
        f"[1:a]volume={args.volume},afade=t=in:st=0:d=0.4,"
        f"afade=t=out:st={seconds - 1.2:.2f}:d=1.2[a]",
        "-map", "0:v", "-map", "[a]", "-shortest",
        "-c:v", "libx264", "-crf", "23", "-preset", "slow", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart",
        "-loglevel", "error", str(out),
    ], check=True)
    silent.unlink()

    print(f"  {frames} frames, {seconds:.1f}s")
    print(f"  music     {track.name} at {args.volume:.0%}")
    for start, end, text, _, _ in lines:
        print(f"  {start:>4.1f}s  {text}")
    print(f"\n  {out}  ({out.stat().st_size / 1048576:.1f} MB)")


if __name__ == "__main__":
    main()
