"""Makes the short vertical videos a campaign runs on, from the real levels.

Each clip is the game's own artwork with Findo composited exactly where the
game would put her, so what a viewer is asked to find is what they will
actually get. The shape is the one that works on these platforms: a slow move
across a crowd, a countdown, and a reveal at the end.

    python tool/make_clips.py                 # a clip per level in the default set
    python tool/make_clips.py --levels 3,7,12 --seconds 9

Deliberately silent and with no words burned in. A clip carries further with
the platform's own trending audio over it and its own text tool on top -- both
are things the feed rewards and a baked-in caption cannot be.

Output: store/clips/level_NN_spotS.mp4, 1080x1920.
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "assets/images/maps"
META = MAPS / "meta"
FINDO = ROOT / "assets/images/targets/findo.png"
OUT = ROOT / "store/clips"

WIDTH, HEIGHT = 1080, 1920
FPS = 30

# The easy end of the ladder. A puzzle nobody solves gets no comments, and the
# comments are the whole point: a viewer who types "top left!" has watched it
# twice and told the feed the clip is worth showing to someone else.
DEFAULT_LEVELS = [1, 2, 3, 5, 7, 9, 11, 14, 17, 21]


def level_meta(index: int) -> dict:
    return json.loads((META / f"level_{index:02d}.json").read_text(encoding="utf-8"))


def scene_with_findo(meta: dict, spot: int) -> tuple[Image.Image, tuple[int, int]]:
    """The map as the game draws it, and where she stands on it, in pixels."""
    scene = Image.open(MAPS.parent / meta["map"]).convert("RGB")
    world = meta["mapSize"]["width"]
    scale = scene.width / world
    target = meta["targets"][spot]

    girl = Image.open(FINDO).convert("RGBA")
    box_w = max(1, round(target["width"] * scale))
    box_h = max(1, round(target["height"] * scale))
    girl = girl.resize((box_w, box_h), Image.LANCZOS)
    x = round(target["x"] * scale)
    y = round(target["y"] * scale)
    scene.paste(girl, (x, y), girl)
    return scene, (x + box_w // 2, y + box_h // 2)


def ease(t: float) -> float:
    """Slow at both ends, so the move reads as a camera and not a scroll."""
    return 0.5 - 0.5 * math.cos(math.pi * min(1.0, max(0.0, t)))


def view_box(scene: Image.Image, centre: tuple[float, float],
             zoom: float) -> tuple[float, float, float, float]:
    """The part of the scene a frame shows, kept inside the picture."""
    view_h = scene.height / zoom
    view_w = view_h * WIDTH / HEIGHT
    cx = min(max(centre[0], view_w / 2), scene.width - view_w / 2)
    cy = min(max(centre[1], view_h / 2), scene.height - view_h / 2)
    return (cx - view_w / 2, cy - view_h / 2, cx + view_w / 2, cy + view_h / 2)


def frame(scene: Image.Image, centre: tuple[float, float], zoom: float) -> Image.Image:
    """A 9:16 crop of the scene, centred where the camera is looking."""
    return scene.resize((WIDTH, HEIGHT), Image.LANCZOS,
                        box=view_box(scene, centre, zoom))


def project(box: tuple[float, float, float, float],
            point: tuple[float, float]) -> tuple[float, float]:
    """Where a place in the scene lands on the frame drawn from [box]."""
    left, top, right, bottom = box
    return ((point[0] - left) / (right - left) * WIDTH,
            (point[1] - top) / (bottom - top) * HEIGHT)


def with_ring(image: Image.Image, at: tuple[float, float], radius: float,
              alpha: int) -> Image.Image:
    """The reveal: everything dims except a circle closing on her."""
    if alpha <= 0:
        return image
    shade = Image.new("RGBA", image.size, (8, 10, 18, alpha))
    hole = Image.new("L", image.size, 255)
    ImageDraw.Draw(hole).ellipse(
        [at[0] - radius, at[1] - radius, at[0] + radius, at[1] + radius], fill=0)
    shade.putalpha(hole.point(lambda v: v * alpha // 255))
    out = image.convert("RGBA")
    out.alpha_composite(shade)
    ring = ImageDraw.Draw(out)
    ring.ellipse([at[0] - radius, at[1] - radius, at[0] + radius, at[1] + radius],
                 outline=(250, 204, 21, 255), width=8)
    return out.convert("RGB")


def build(index: int, spot: int, seconds: float,
          reveal: bool = True) -> Path:
    meta = level_meta(index)
    scene, her = scene_with_findo(meta, spot)

    # Wide, and barely moving.
    #
    # The first version drifted in close, and by the halfway mark it framed
    # twenty people with her plainly among them -- which is not the game and
    # gives a viewer nothing to do. The whole appeal is one girl among
    # hundreds, so the search has to happen at a zoom where hundreds are on
    # screen. This holds the widest view a 9:16 frame can take of a square map
    # -- its full height, a bit over half its width -- and drifts a few percent
    # across it, so the shot breathes without ever sweeping past the answer.
    #
    # She is inside the frame the whole time, off to one side. She is meant to
    # be findable and hard, not hidden off screen.
    total = int(seconds * FPS)
    # Without the reveal the clip is all search, and the answer goes in the
    # comments instead. It draws more of them -- a viewer who was not shown
    # will ask, and the ones who found her will answer each other -- at the
    # risk of feeling like a cheat. Worth a few clips, not all of them.
    reveal_at = int(total * 0.74) if reveal else total

    wide = 1.02
    view_h = scene.height / wide
    view_w = view_h * WIDTH / HEIGHT
    # A third of the way in from an edge, alternating by spot so a run of
    # clips does not put her in the same place every time.
    offset = (0.33 if spot % 2 == 0 else 0.67) - 0.5
    start = (her[0] - view_w * offset - view_w * 0.04,
             her[1] - view_h * 0.03)
    end = (her[0] - view_w * offset + view_w * 0.04,
           her[1] + view_h * 0.03)

    OUT.mkdir(parents=True, exist_ok=True)
    name = f"level_{index:02d}_spot{spot}_{int(seconds)}s"
    path = OUT / f"{name}{'' if reveal else '_noreveal'}.mp4"
    writer = imageio_ffmpeg.write_frames(
        str(path), (WIDTH, HEIGHT), fps=FPS, quality=8,
        macro_block_size=8, ffmpeg_log_level="error",
    )
    writer.send(None)
    for i in range(total):
        if i < reveal_at:
            drift = i / max(1, reveal_at - 1)
            centre = (start[0] + (end[0] - start[0]) * drift,
                      start[1] + (end[1] - start[1]) * drift)
            writer.send(frame(scene, centre, wide).tobytes())
            continue
        # The reveal: the camera closes on her while a ring tightens and the
        # rest of the crowd goes dark, so the answer is shown rather than
        # claimed.
        k = ease((i - reveal_at) / max(1, total - reveal_at))
        centre = (end[0] + (her[0] - end[0]) * k,
                  end[1] + (her[1] - end[1]) * k)
        box = view_box(scene, centre, wide + (2.6 - wide) * k)
        image = scene.resize((WIDTH, HEIGHT), Image.LANCZOS, box=box)
        # On her, not on the middle of the frame. A hiding place near an edge
        # of the map is one the camera cannot centre on -- it would have to
        # look past the edge of the picture -- so the ring drawn at the middle
        # of the frame closed on whoever happened to be standing there. A
        # reveal that circles the wrong person is worse than no reveal.
        radius = WIDTH * (0.75 - 0.52 * k)
        image = with_ring(image, project(box, her), radius, int(200 * k))
        writer.send(image.tobytes())
    writer.close()
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--levels", default=",".join(str(n) for n in DEFAULT_LEVELS))
    parser.add_argument("--spot", type=int, default=0)
    parser.add_argument("--seconds", type=float, default=10.0)
    parser.add_argument("--no-reveal", action="store_true", dest="no_reveal",
                        help="end on the crowd; the answer goes in the comments")
    args = parser.parse_args()

    for index in [int(n) for n in args.levels.split(",") if n.strip()]:
        meta = level_meta(index)
        spot = min(args.spot, len(meta["targets"]) - 1)
        path = build(index, spot, args.seconds, reveal=not args.no_reveal)
        size = path.stat().st_size / 1048576
        print(f"  level {index:>3} spot {spot}: {path.name}  {size:.1f} MB")
    print(f"\n{OUT}")


if __name__ == "__main__":
    main()
