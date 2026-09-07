"""Registers a map with the game and writes its level metadata.

This is the seam between artwork and code. Drop a hand-drawn map into
`assets/images/maps/`, tell this tool where Findo is hiding in it, and the game
picks it up -- no Dart changes.

    # add a new map, with Findo's top-left corner and size in map pixels
    python tool/level_data.py register --map assets/images/maps/level_04.png \\
        --id level_04 --index 4 --name-key level.harbour \\
        --target 1180 640 96 176 --time 120

    # check every registered map still lines up with its image
    python tool/level_data.py verify

Levels are listed in `assets/images/maps/meta/index.json`; one JSON file per
level sits beside it.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "assets" / "images" / "maps"
META = MAPS / "meta"
INDEX = META / "index.json"

# Play sessions run at up to 3.2x the fit-to-screen zoom; below this the map
# turns to mush at full magnification on a modern phone.
MIN_MAP_SIDE = 2048


def star_thresholds(time_limit: int) -> tuple[int, int, int]:
    """Score is 100 for the find plus 10 per second left on the clock, so the
    ceiling is 100 + time_limit * 10 and it is only reached by finding her the
    instant the level opens. These cuts ask for the level to be cleared inside
    roughly the first 28%, 55% and 90% of the time allowed -- demanding at the
    top, but reachable, which a flat 1400 was not."""
    ceiling = time_limit * 10
    return (
        round(100 + ceiling * 0.10),
        round(100 + ceiling * 0.45),
        round(100 + ceiling * 0.72),
    )


def load_index() -> list[str]:
    if not INDEX.exists():
        return []
    return json.loads(INDEX.read_text(encoding="utf-8"))["levels"]


def save_index(ids: list[str]) -> None:
    META.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps({"levels": ids}, indent=2) + "\n", encoding="utf-8")


def write_level(
    *,
    level_id: str,
    index: int,
    name_key: str,
    map_rel: str,
    map_size: tuple[int, int],
    target: tuple[int, int, int, int],
    time_limit: int,
    stars: tuple[int, int, int],
) -> Path:
    """Writes one level's metadata and makes sure it is listed in the index."""
    x, y, w, h = target
    data = {
        "id": level_id,
        "index": index,
        "nameKey": name_key,
        "map": map_rel,
        "mapSize": {"width": map_size[0], "height": map_size[1]},
        "timeLimitSeconds": time_limit,
        "starThresholds": {"one": stars[0], "two": stars[1], "three": stars[2]},
        "target": {"x": x, "y": y, "width": w, "height": h},
    }
    META.mkdir(parents=True, exist_ok=True)
    path = META / f"{level_id}.json"
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    ids = load_index()
    if level_id not in ids:
        ids.append(level_id)
    ids.sort(key=lambda i: json.loads((META / f"{i}.json").read_text(encoding="utf-8"))["index"])
    save_index(ids)
    return path


def _check(level_id: str) -> list[str]:
    """Returns a list of problems with one level, empty when it is sound."""
    problems: list[str] = []
    meta_path = META / f"{level_id}.json"
    if not meta_path.exists():
        return [f"{level_id}: no metadata file"]

    data = json.loads(meta_path.read_text(encoding="utf-8"))
    image_path = ROOT / "assets" / "images" / data["map"]
    if not image_path.exists():
        return [f"{level_id}: map image missing at {data['map']}"]

    with Image.open(image_path) as im:
        width, height = im.size

    if (width, height) != (data["mapSize"]["width"], data["mapSize"]["height"]):
        problems.append(
            f"{level_id}: metadata says {data['mapSize']['width']}x"
            f"{data['mapSize']['height']}, image is {width}x{height}"
        )
    if min(width, height) < MIN_MAP_SIDE:
        problems.append(
            f"{level_id}: {width}x{height} is below the {MIN_MAP_SIDE}px minimum, "
            "so it will blur at full zoom"
        )

    t = data["target"]
    if t["x"] < 0 or t["y"] < 0 or t["x"] + t["width"] > width or t["y"] + t["height"] > height:
        problems.append(f"{level_id}: Findo's box falls outside the map")
    if t["width"] < 24 or t["height"] < 24:
        problems.append(f"{level_id}: Findo's box is too small to tap reliably")
    return problems


def cmd_register(args: argparse.Namespace) -> int:
    map_path = Path(args.map)
    if not map_path.is_absolute():
        map_path = ROOT / map_path
    if not map_path.exists():
        print(f"no such map: {map_path}", file=sys.stderr)
        return 1

    with Image.open(map_path) as im:
        size = im.size

    try:
        map_rel = map_path.relative_to(ROOT / "assets" / "images").as_posix()
    except ValueError:
        print("the map must live under assets/images/", file=sys.stderr)
        return 1

    write_level(
        level_id=args.id,
        index=args.index,
        name_key=args.name_key,
        map_rel=map_rel,
        map_size=size,
        target=tuple(args.target),
        time_limit=args.time,
        stars=tuple(args.stars) if args.stars else star_thresholds(args.time),
    )
    stars = tuple(args.stars) if args.stars else star_thresholds(args.time)
    print(f"registered {args.id}: {map_rel} {size[0]}x{size[1]}, "
          f"{args.time}s, stars at {stars[0]}/{stars[1]}/{stars[2]}")
    problems = _check(args.id)
    for problem in problems:
        print(f"  warning: {problem}")
    return 0


def cmd_verify(_: argparse.Namespace) -> int:
    ids = load_index()
    if not ids:
        print("no levels registered")
        return 1
    problems: list[str] = []
    for level_id in ids:
        problems.extend(_check(level_id))
    for problem in problems:
        print(problem)
    if problems:
        print(f"\n{len(problems)} problem(s) in {len(ids)} level(s)")
        return 1
    print(f"{len(ids)} level(s) verified")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    reg = sub.add_parser("register", help="add or update a map")
    reg.add_argument("--map", required=True, help="path to the map image")
    reg.add_argument("--id", required=True, help="level id, e.g. level_04")
    reg.add_argument("--index", type=int, required=True, help="1-based play order")
    reg.add_argument("--name-key", required=True, dest="name_key",
                     help="translation key for the level name")
    reg.add_argument("--target", nargs=4, type=int, required=True,
                     metavar=("X", "Y", "W", "H"),
                     help="Findo's box in map pixels")
    reg.add_argument("--time", type=int, default=120, help="time limit in seconds")
    reg.add_argument("--stars", nargs=3, type=int, default=None,
                     metavar=("ONE", "TWO", "THREE"),
                     help="score for 1, 2 and 3 stars; derived from --time if omitted")
    reg.set_defaults(func=cmd_register)

    ver = sub.add_parser("verify", help="check every registered level")
    ver.set_defaults(func=cmd_verify)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
