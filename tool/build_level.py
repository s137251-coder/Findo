"""Turns generated artwork into a playable level.

Image models will not draw the same character twice. Ask one for a crowded
scene *with* Findo in it ten times and you get ten different girls, none of
whose positions you know. So the workflow splits in two: the model draws the
crowd, and Findo is composited in afterwards from a single master. She is then
identical on every map and her coordinates are exact by construction.

    # once: clean up the character sheet the model produced
    python tool/build_level.py character --image ~/Downloads/findo_raw.png

    # per level: fit the scene, drop her in, register it
    python tool/build_level.py level --scene ~/Downloads/beach.png \\
        --id level_04 --index 4 --name-key level.beach \\
        --feet 1180 1490 --height 115 --time 140

`--feet` is where her shoes touch the ground, in map pixels after the scene has
been fitted to 2048x2048. `--height` is her full height, from the table in
docs/ART_BRIEF.md. Both commands write a preview so you can see what landed
where before trusting it.
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image

from level_data import MAPS, MIN_MAP_SIDE, ROOT, star_thresholds, write_level

TARGETS = ROOT / "assets" / "images" / "targets"
FINDO = TARGETS / "findo.png"
PREVIEWS = ROOT / "store" / "previews"

MAP_SIDE = 2048

# How close a pixel must be to the corner colour to count as background.
KEY_TOLERANCE = 68

# Findo's skirt. The brief says this colour is hers alone on every map, because
# it is the one thing a player's eye can be trained on. Generators do not obey
# that, so the rule is enforced here instead of hoped for.
FINDO_SKIRT = (146, 62, 168)
ALTERNATE_PURPLE = (108, 82, 176)
SKIRT_TOLERANCE = 70


def fit_square(image: Image.Image, side: int = MAP_SIDE) -> tuple[Image.Image, str]:
    """Centre-crops to square, then scales to exactly [side].

    Returns the image and a note about what had to be done, so the caller can
    warn when the source was too small to survive full zoom.
    """
    notes = []
    width, height = image.size
    if width != height:
        edge = min(width, height)
        left = (width - edge) // 2
        top = (height - edge) // 2
        image = image.crop((left, top, left + edge, top + edge))
        notes.append(f"centre-cropped {width}x{height} to {edge}x{edge}")
        width = height = edge

    if width < MIN_MAP_SIDE:
        notes.append(
            f"source was only {width}px; upscaled to {side}px, so it will look "
            f"soft at full zoom -- regenerate larger if you can"
        )
    if width != side:
        image = image.resize((side, side), Image.LANCZOS)
        notes.append(f"scaled {width}px to {side}px")

    return image.convert("RGB"), "; ".join(notes) or "already the right size"


def free_the_skirt_colour(scene: Image.Image) -> tuple[Image.Image, int]:
    """Shifts anything already wearing Findo's violet to a different purple.

    Without this a crowd can contain a figure in her exact skirt -- and in the
    supplied Fountain Square artwork one of them also wore a yellow top, which
    is two of her three signature traits and reads as a second Findo the game
    cannot register. Each matching pixel keeps its own deviation from the
    source colour, so shading and outlines survive the shift.
    """
    import numpy as np

    pixels = np.asarray(scene.convert("RGB")).astype(np.int16)
    source = np.array(FINDO_SKIRT, dtype=np.int16)
    target = np.array(ALTERNATE_PURPLE, dtype=np.int16)

    distance = np.abs(pixels - source).sum(axis=2)
    hit = distance < SKIRT_TOLERANCE
    count = int(hit.sum())
    if count:
        pixels[hit] = np.clip(pixels[hit] - source + target, 0, 255)

    return Image.fromarray(pixels.astype("uint8"), "RGB"), count


def key_out_background(image: Image.Image, tolerance: int = KEY_TOLERANCE) -> Image.Image:
    """Makes the flat backdrop transparent.

    Two passes. The first floods in from the edges, which is what clears the
    soft anti-aliased fringe where the figure meets the backdrop. The second
    sweeps the whole image for the same colour, because the first cannot reach
    background trapped inside the silhouette -- under a chin, between an arm and
    the body. That second pass is only safe because the prompt asks for a
    backdrop colour the character does not wear; if you key against a colour she
    uses, it will eat holes in her.
    """
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()

    corners = [pixels[0, 0], pixels[width - 1, 0], pixels[0, height - 1], pixels[width - 1, height - 1]]
    key = max(set(corners), key=corners.count)

    def matches(px) -> bool:
        return sum(abs(px[i] - key[i]) for i in range(3)) <= tolerance

    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            queue.append((x, y))

    removed = 0
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        idx = y * width + x
        if seen[idx]:
            continue
        seen[idx] = 1
        if not matches(pixels[x, y]):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        removed += 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # Second pass: background the flood could not reach.
    enclosed = 0
    for y in range(height):
        for x in range(width):
            px = pixels[x, y]
            if px[3] and matches(px):
                pixels[x, y] = (0, 0, 0, 0)
                enclosed += 1

    print(f"  keyed out {removed:,} pixels from the edges and {enclosed:,} "
          f"enclosed, around rgb{key[:3]}")
    box = image.getbbox()
    return image.crop(box) if box else image


def cmd_character(args: argparse.Namespace) -> int:
    source = Path(args.image).expanduser()
    if not source.exists():
        print(f"no such image: {source}", file=sys.stderr)
        return 1

    image = Image.open(source)
    print(f"source: {image.size[0]}x{image.size[1]}")
    sheet = key_out_background(image, args.tolerance)

    if sheet.height < 800:
        print(f"  warning: only {sheet.height}px tall after trimming; the brief "
              f"asks for 800px or more")

    TARGETS.mkdir(parents=True, exist_ok=True)
    sheet.save(FINDO)
    print(f"wrote {FINDO.relative_to(ROOT)} at {sheet.size[0]}x{sheet.size[1]}")

    # A checkerboard preview makes a bad key obvious at a glance.
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    tile = 16
    board = Image.new("RGB", sheet.size, (235, 235, 238))
    for y in range(0, sheet.height, tile):
        for x in range(0, sheet.width, tile):
            if (x // tile + y // tile) % 2:
                board.paste((205, 205, 212), (x, y, min(x + tile, sheet.width), min(y + tile, sheet.height)))
    board.paste(sheet, (0, 0), sheet)
    board.save(PREVIEWS / "character.png")
    print(f"preview: {(PREVIEWS / 'character.png').relative_to(ROOT)}")
    return 0


def cmd_level(args: argparse.Namespace) -> int:
    scene_path = Path(args.scene).expanduser()
    if not scene_path.exists():
        print(f"no such scene: {scene_path}", file=sys.stderr)
        return 1
    if not FINDO.exists():
        print("no character sheet yet -- run the 'character' command first",
              file=sys.stderr)
        return 1

    scene, note = fit_square(Image.open(scene_path))
    print(f"scene: {note}")

    scene, recoloured = free_the_skirt_colour(scene)
    if recoloured:
        print(f"  shifted {recoloured:,} pixels off Findo's skirt colour, so it "
              f"is hers alone on this map")

    findo = Image.open(FINDO).convert("RGBA")
    height = args.height
    width = max(1, round(findo.width * height / findo.height))
    findo = findo.resize((width, height), Image.LANCZOS)

    feet_x, feet_y = args.feet
    x = feet_x - width // 2
    y = feet_y - height

    margin = 140
    if not (margin <= x and margin <= y
            and x + width <= MAP_SIDE - margin and y + height <= MAP_SIDE - margin):
        print(f"  warning: she lands at ({x}, {y}) {width}x{height}, which is "
              f"inside the {margin}px edge margin the brief asks for")

    scene.paste(findo, (x, y), findo)

    MAPS.mkdir(parents=True, exist_ok=True)
    # WebP, not PNG. These are dense illustrations: the same map is 5.9 MB as a
    # PNG and 0.8 MB as WebP at quality 92, and ten of them is the difference
    # between a 15 MB download and a 60 MB one. Flutter decodes WebP on both
    # Android and iOS. Hand-drawn masters stay lossless PNG; this is only the
    # shipping copy.
    map_name = f"{args.id}.webp"
    scene.save(MAPS / map_name, "WEBP", quality=92, method=6)
    size_mb = (MAPS / map_name).stat().st_size / 1_048_576
    print(f"wrote {(MAPS / map_name).relative_to(ROOT)} at {MAP_SIDE}x{MAP_SIDE}, {size_mb:.2f} MB")
    if size_mb > 1.5:
        print("  warning: over the 1.5 MB per-map budget in the brief")

    stars = star_thresholds(args.time)
    write_level(
        level_id=args.id,
        index=args.index,
        name_key=args.name_key,
        map_rel=f"maps/{map_name}",
        map_size=(MAP_SIDE, MAP_SIDE),
        target=(x, y, width, height),
        time_limit=args.time,
        stars=stars,
    )
    print(f"registered {args.id}: Findo at ({x}, {y}) {width}x{height}, "
          f"{args.time}s, stars at {stars[0]}/{stars[1]}/{stars[2]}")

    # Crop around her so you can check she is hidden, not stranded.
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    pad = 320
    crop = scene.crop((
        max(0, x - pad), max(0, y - pad),
        min(MAP_SIDE, x + width + pad), min(MAP_SIDE, y + height + pad),
    ))
    crop.save(PREVIEWS / f"{args.id}_where.png")
    scene.resize((512, 512), Image.LANCZOS).save(PREVIEWS / f"{args.id}_map.png")
    print(f"preview: store/previews/{args.id}_where.png and {args.id}_map.png")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    ch = sub.add_parser("character", help="clean up a generated character sheet")
    ch.add_argument("--image", required=True, help="the raw image from the model")
    ch.add_argument("--tolerance", type=int, default=KEY_TOLERANCE,
                    help="how close to the corner colour still counts as background")
    ch.set_defaults(func=cmd_character)

    lv = sub.add_parser("level", help="composite Findo into a scene and register it")
    lv.add_argument("--scene", required=True, help="the crowd scene, without Findo")
    lv.add_argument("--id", required=True)
    lv.add_argument("--index", type=int, required=True)
    lv.add_argument("--name-key", required=True, dest="name_key")
    lv.add_argument("--feet", nargs=2, type=int, required=True, metavar=("X", "Y"),
                    help="where her shoes touch the ground, in map pixels")
    lv.add_argument("--height", type=int, required=True,
                    help="her full height in map pixels, from the brief's table")
    lv.add_argument("--time", type=int, required=True, help="time limit in seconds")
    lv.set_defaults(func=cmd_level)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
