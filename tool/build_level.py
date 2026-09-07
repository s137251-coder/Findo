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

# How far a tinted Findo is allowed to travel towards the scene's ambient
# colour. Past this she stops being recognisable as the girl on the objective
# panel, which is the one thing the player has to go on.
MAX_TINT = 0.55


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


def scene_tint(scene: Image.Image, strength: float):
    """A multiplier that puts Findo under the same light as the map.

    A daylit character dropped into a dusk scene is the brightest thing in it,
    which makes the hardest level the easiest. The gain is applied to her
    sprite at runtime, so it holds wherever on the map she turns up.
    """
    import numpy as np

    pixels = np.asarray(scene.convert("RGB")).astype(np.float32)
    ambient = np.median(pixels.reshape(-1, 3), axis=0)
    neutral = 150.0
    gain = np.clip(ambient / neutral, 0.25, 1.4)
    gain = 1.0 + (gain - 1.0) * strength
    return ambient, tuple(float(g) for g in gain)


def _box_sums(mask, window: int):
    """Sum of `mask` over every window x window square, as an integral image."""
    import numpy as np

    total = np.cumsum(np.cumsum(mask, axis=0), axis=1)
    total = np.pad(total, ((1, 0), (1, 0)))
    return (total[window:, window:] - total[:-window, window:]
            - total[window:, :-window] + total[:-window, :-window])


def people_mask(scene: Image.Image):
    """Where the people are, as opposed to where skin-coloured paint is.

    Colour alone is not enough. A plain skin-tone test also selects tan
    stucco, sand, cardboard and pine, and an earlier version of this put Findo
    on a stable wall, on a chalet roof and standing in a first-floor window box.

    What separates a face from a facade is size: a face is a patch tens of
    pixels across surrounded by things that are not skin, while a wall is
    thousands of pixels of it. So the colour mask is kept only where the
    surrounding 96px square is mostly *not* skin, which erases large fields of
    it and leaves faces and hands behind.
    """
    import numpy as np

    pixels = np.asarray(scene.convert("RGB")).astype(np.int16)
    r, g, b = pixels[:, :, 0], pixels[:, :, 1], pixels[:, :, 2]
    skin = ((r > 140) & (r > g + 12) & (g > b + 6)
            & (r - b > 28) & (r - b < 130) & (r < 252)).astype(np.float32)

    window = 96
    fraction = _box_sums(skin, window) / float(window * window)
    # Pad the fraction back to full size so it lines up with the mask; the
    # border is unusable anyway, the margin keeps her well clear of it.
    isolated = np.zeros_like(skin)
    half = window // 2
    isolated[half:half + fraction.shape[0], half:half + fraction.shape[1]] = (
        fraction < 0.28)
    return skin * isolated


def _against_sky(pixels, fx: int, fy: int, width: int, height: int) -> bool:
    """Would she be standing in open sky here?

    A figure on a battlement or a rooftop is outlined against a big flat field
    of blue, which makes her the easiest thing on the map to find -- the
    opposite of what the late levels want. Ground can be just as flat (a lawn,
    a plaza) and is perfectly good cover, so the test is specifically for sky
    rather than for flatness.
    """
    import numpy as np

    pad = max(width, 24)
    y0 = max(0, fy - height - pad)
    y1 = min(pixels.shape[0], fy)
    x0 = max(0, fx - width // 2 - pad)
    x1 = min(pixels.shape[1], fx + width // 2 + pad)
    patch = pixels[y0:y1, x0:x1].astype(np.int16)
    if patch.size == 0:
        return True

    r, g, b = patch[:, :, 0], patch[:, :, 1], patch[:, :, 2]
    # Daylight sky and the pale blue-grey overcast these scenes use: blue
    # leads, nothing is dark, and it never goes green.
    sky = (b > r + 12) & (b > 150) & (g > r) & (r > 90)
    return float(sky.mean()) > 0.42


def find_spots(scene: Image.Image, count: int, width: int, height: int,
               margin: int = 140, separation: int = 520):
    """Picks places to hide her: among people, and far enough apart to matter.

    Two spots 200px apart on a 2048px map are the same hiding place as far as
    a player is concerned, so the separation is what makes a replay feel like
    a new hunt. It is relaxed rather than abandoned when a map has fewer
    distinct crowds, because two real spots beat five that overlap.
    """
    import numpy as np

    people = people_mask(scene)
    backdrop = np.asarray(scene.convert("RGB"))
    window = 200
    density = _box_sums(people, window)

    # Only consider feet positions that leave her fully inside the margin.
    side = scene.size[0]
    low_x, high_x = margin + width // 2, side - margin - width // 2
    low_y, high_y = margin + height, side - margin

    # A spot has to sit in a genuine crowd, not on the one stray face in an
    # empty corner, or she ends up somewhere nobody would think to look.
    floor = max(160.0, float(density.max()) * 0.12)

    best = []
    for gap in (separation, int(separation * 0.75), int(separation * 0.55)):
        spots = []
        scores = density.copy()
        for _ in range(count):
            if scores.max() < floor:
                break
            order = np.argsort(scores, axis=None)[::-1]
            chosen = None
            for index in order[:20000]:
                if scores.flat[index] < floor:
                    break
                yy, xx = np.unravel_index(index, scores.shape)
                fx, fy = int(xx + window // 2), int(yy + window // 2)
                if not (low_x <= fx <= high_x and low_y <= fy <= high_y):
                    continue
                if any((fx - px) ** 2 + (fy - py) ** 2 < gap ** 2
                       for px, py in spots):
                    continue
                if _against_sky(backdrop, fx, fy, width, height):
                    continue
                chosen = (fx, fy)
                break
            if chosen is None:
                break
            spots.append(chosen)
            cx, cy = chosen[0] - window // 2, chosen[1] - window // 2
            y0, y1 = max(0, cy - gap), min(scores.shape[0], cy + gap)
            x0, x1 = max(0, cx - gap), min(scores.shape[1], cx + gap)
            scores[y0:y1, x0:x1] = 0
        if len(spots) > len(best):
            best = spots
        if len(best) >= count:
            break

    return [(fx - width // 2, fy - height, width, height) for fx, fy in best]


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

    # Her aspect ratio puts a floor on how small she can be asked to go: a
    # standing figure is about a third as wide as she is tall, so shrinking her
    # for difficulty runs out of tap target before it runs out of height.
    if width < 24:
        needed = -(-24 * findo.height // findo.width)
        print(f"  warning: at {height} px tall she is only {width} px wide, "
              f"under the 24 px the verifier requires. Use --height {needed} "
              f"or more")

    # The map ships without her on it. She is drawn by the game at one of these
    # spots, chosen when the level opens, so replaying a level is a fresh
    # search instead of a memory test.
    spots = find_spots(scene, args.spots, width, height)
    if not spots:
        print("could not find anywhere crowded enough to hide her", file=sys.stderr)
        return 1
    if len(spots) < args.spots:
        print(f"  note: found {len(spots)} usable hiding spots, not {args.spots}; "
              f"this map has fewer well-separated crowds than asked for")

    tint = None
    if args.tint > 0:
        strength = min(args.tint, MAX_TINT)
        ambient, tint = scene_tint(scene, strength)
        print(f"  tint {strength:.2f} towards ambient "
              f"rgb({ambient[0]:.0f}, {ambient[1]:.0f}, {ambient[2]:.0f}); "
              f"gain {tint[0]:.2f}/{tint[1]:.2f}/{tint[2]:.2f}")

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
        targets=spots,
        time_limit=args.time,
        stars=stars,
        tint=tint,
    )
    where = ", ".join(f"({x},{y})" for x, y, _, _ in spots)
    print(f"registered {args.id}: {len(spots)} hiding spots at {where}, "
          f"{width}x{height}, {args.time}s, stars at {stars[0]}/{stars[1]}/{stars[2]}")

    # One preview per spot, so each can be checked for being among people
    # rather than stranded. She is pasted here for the preview only.
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    sprite = findo.resize((width, height), Image.LANCZOS)
    pad = 300
    for i, (x, y, w, h) in enumerate(spots):
        shot = scene.copy()
        shot.paste(sprite, (x, y), sprite)
        shot.crop((max(0, x - pad), max(0, y - pad),
                   min(MAP_SIDE, x + w + pad),
                   min(MAP_SIDE, y + h + pad))).save(
            PREVIEWS / f"{args.id}_spot{i}.png")
    scene.resize((512, 512), Image.LANCZOS).save(PREVIEWS / f"{args.id}_map.png")
    print(f"preview: store/previews/{args.id}_spot0..{len(spots) - 1}.png")
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
    lv.add_argument("--spots", type=int, default=5,
                    help="how many hiding places to find. The game picks one "
                         "per play, so a replay is a fresh search")
    lv.add_argument("--height", type=int, required=True,
                    help="her full height in map pixels, from the brief's table")
    lv.add_argument("--time", type=int, required=True, help="time limit in seconds")
    lv.add_argument("--tint", type=float, default=0.0,
                    help="0 to 0.55: blend her towards the scene's own light. Use "
                         "on dusk or night maps, where a daylit figure is the "
                         "brightest thing on the map and gives itself away")
    lv.set_defaults(func=cmd_level)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
