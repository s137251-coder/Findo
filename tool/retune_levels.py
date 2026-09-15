"""Re-applies the difficulty table to levels that are already built.

    python tool/retune_levels.py            show what would change
    python tool/retune_levels.py --write    write it

`levels.csv` is the difficulty curve, but it is only read when a level is
*built* from artwork. Changing a number in it does nothing to the twenty-nine
levels already on disk. This rewrites their metadata from the table -- time
limit, figure size, star thresholds and motion -- without re-rendering a single
map, which takes minutes per level and needs the source scenes to hand.

Safe to run repeatedly: it only touches the four fields it owns, and leaves the
hiding spots, tint and map reference exactly as they were.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from level_data import META, star_thresholds  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "tool" / "levels.csv"

# findo.png is 616 x 1758. Her box is derived from this so she is never
# stretched by a level's rounding.
SPRITE_RATIO = 616 / 1758


def load_table() -> dict[int, dict[str, str]]:
    with TABLE.open(encoding="utf-8") as handle:
        return {int(row["index"]): row for row in csv.DictReader(handle)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="apply the changes; without it nothing is written")
    args = parser.parse_args()

    table = load_table()
    changed = 0
    untouched = 0

    for path in sorted(META.glob("level_*.json")):
        level = json.loads(path.read_text(encoding="utf-8"))
        row = table.get(level["index"])
        if row is None:
            print(f"  {path.stem}: not in levels.csv, left alone")
            continue

        time = int(row["time"])
        height = int(row["height"])
        # Width comes from the sprite's own proportions, not from the box the
        # level happens to carry: those have accumulated rounding, and one of
        # them was already a pixel under the 24 the game needs to keep her
        # tappable. Deriving it fresh each time keeps her undistorted and above
        # that floor at every height the table allows.
        first = level["targets"][0]
        width = max(1, round(height * SPRITE_RATIO))
        one, two, three = star_thresholds(time)
        motion = float(row.get("motion") or 0)

        before = (
            level["timeLimitSeconds"],
            first["width"], first["height"],
            level["starThresholds"],
            level.get("motion", 0),
        )

        level["timeLimitSeconds"] = time
        for target in level["targets"]:
            # A spot is where her feet are: the builder chose it so she stands
            # among people. Resizing the box from its top-left corner would
            # walk her feet down and sideways by the size difference -- 32
            # units when she grows from 68 to 100 -- so the box is re-anchored
            # on the feet instead.
            feet_x = target["x"] + target["width"] / 2
            feet_y = target["y"] + target["height"]
            target["width"] = width
            target["height"] = height
            target["x"] = max(0, round(feet_x - width / 2))
            target["y"] = max(0, round(feet_y - height))
        level["starThresholds"] = {"one": one, "two": two, "three": three}
        level["motion"] = motion

        after = (time, width, height,
                 level["starThresholds"], motion)
        if before == after:
            untouched += 1
            continue

        changed += 1
        print(f"  {path.stem}: {before[0]}s -> {time}s, "
              f"{before[1]}x{before[2]} -> {width}x{height}, "
              f"3-star {before[3]['three']} -> {three}, "
              f"motion {before[4]} -> {motion}")
        if args.write:
            path.write_text(
                json.dumps(level, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

    print()
    print(f"{changed} level(s) {'rewritten' if args.write else 'would change'}, "
          f"{untouched} already matched the table")
    if changed and not args.write:
        print("nothing was written; pass --write to apply")


if __name__ == "__main__":
    main()
