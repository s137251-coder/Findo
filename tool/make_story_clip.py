"""Joins the generated opening to a tail built from the real game map.

The video model does one girl in motion beautifully and a crowd of hundreds
badly: asked for a figure a thirtieth of the frame it returns one eight times
that, because it understands her as the subject of the shot and sizes her
accordingly. Three attempts at saying otherwise did not move it.

So the clip is cut where the model stops being good at it. Its opening is
kept -- a real girl waving, an illustrated world building around her, and her
walking away into it -- and the ending is drawn here from the level's own
artwork, with Findo composited at the size and the place the game would put
her. That fixes the size by construction, and it means the crowd a viewer
searches is the one they get when they install.

    python tool/make_story_clip.py --source <the generated mp4>

The change from girl to drawing is the join itself: a white sweep up the frame
that lands on the drawn world.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_clips import (FINDO, MAPS, META, WIDTH, HEIGHT, level_meta,  # noqa: E402
                        ease, scene_with_findo, view_box)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store/clips"

# 24, because that is what the generated footage runs at and resampling a pan
# to 30 puts a stutter through the half of the clip that came from the model.
FPS = 24


def read_opening(path: Path, seconds: float) -> list[Image.Image]:
    """The generated clip, up to the point where the model takes her over.

    It is cut before its own transformation: that is the shot where she comes
    back eight times too big.
    """
    reader = imageio_ffmpeg.read_frames(str(path), output_params=["-vsync", "0"])
    meta = reader.__next__()
    w, h = meta["size"]
    wanted = int(seconds * FPS)
    frames = []
    for raw in reader:
        image = Image.frombytes("RGB", (w, h), raw)
        if (w, h) != (WIDTH, HEIGHT):
            image = image.resize((WIDTH, HEIGHT), Image.LANCZOS)
        frames.append(image)
        if len(frames) >= wanted:
            break
    return frames


def tail(index: int, spot: int, seconds: float, hold: float) -> list[Image.Image]:
    """The camera keeps rising over the real map, then stops and waits.

    It starts close enough that her size roughly matches where the opening
    left her, and ends at the widest view a 9:16 frame can take of a square
    map: the whole of its height, which is the game's own scale.
    """
    meta = level_meta(index)
    scene, her = scene_with_findo(meta, spot)

    near, wide = 2.6, 1.02
    view_h = scene.height / wide
    view_w = view_h * WIDTH / HEIGHT
    # She ends a third of the way in from an edge rather than in the middle.
    settled = (her[0] - view_w * (0.34 - 0.5), her[1])

    frames = []
    moving = int(seconds * FPS)
    for i in range(moving):
        k = ease(i / max(1, moving - 1))
        zoom = near + (wide - near) * k
        centre = (her[0] + (settled[0] - her[0]) * k,
                  her[1] + (settled[1] - her[1]) * k)
        frames.append(scene.resize((WIDTH, HEIGHT), Image.LANCZOS,
                                   box=view_box(scene, centre, zoom)))
    frames += [frames[-1]] * int(hold * FPS)
    return frames


def sweep(last: Image.Image, first: Image.Image, frames: int) -> list[Image.Image]:
    """The change: a white band travels up the frame and the world behind it
    has become a drawing.

    It does the work of the transformation the model was asked for, and it
    covers the seam between two different pictures of a funfair, which is the
    one thing a straight cut would show.
    """
    out = []
    band = HEIGHT // 7
    for i in range(frames):
        k = (i + 1) / frames
        edge = int(HEIGHT * (1 - k))
        canvas = last.copy()
        canvas.paste(first.crop((0, edge, WIDTH, HEIGHT)), (0, edge))
        # The band itself, fading as it goes so it does not read as a wipe.
        strip = np.asarray(canvas).astype(float)
        top = max(0, edge - band)
        if edge > top:
            fade = np.linspace(0.15, 0.95, edge - top)[:, None, None]
            strip[top:edge] = strip[top:edge] * (1 - fade) + 255 * fade
        out.append(Image.fromarray(strip.astype(np.uint8)))
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="the generated mp4")
    parser.add_argument("--cut", type=float, default=5.8,
                        help="seconds of the generated clip to keep")
    parser.add_argument("--level", type=int, default=3)
    parser.add_argument("--spot", type=int, default=3)
    parser.add_argument("--pull", type=float, default=3.4,
                        help="seconds of the camera still rising")
    parser.add_argument("--hold", type=float, default=2.6,
                        help="seconds held still on the crowd")
    parser.add_argument("--name", default="story_clip.mp4")
    args = parser.parse_args()

    opening = read_opening(Path(args.source), args.cut)
    ending = tail(args.level, args.spot, args.pull, args.hold)
    join = sweep(opening[-1], ending[0], int(0.35 * FPS))
    frames = opening + join + ending

    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / args.name
    writer = imageio_ffmpeg.write_frames(
        str(path), (WIDTH, HEIGHT), fps=FPS, quality=8,
        macro_block_size=8, ffmpeg_log_level="error",
    )
    writer.send(None)
    for image in frames:
        writer.send(image.tobytes())
    writer.close()

    print(f"  opening   {len(opening) / FPS:.1f}s from {Path(args.source).name}")
    print(f"  change    {len(join) / FPS:.1f}s")
    print(f"  the hunt  {len(ending) / FPS:.1f}s on level {args.level}, spot {args.spot}")
    print(f"  total     {len(frames) / FPS:.1f}s -> {path} "
          f"({path.stat().st_size / 1048576:.1f} MB)")


if __name__ == "__main__":
    main()
