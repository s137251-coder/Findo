"""Register every level whose artwork has arrived, in one command.

Reads `tool/levels.csv` -- the hundred-level ladder, one row per level, with
the figure height, time limit and tint each one wants -- looks in a folder for
a scene named after each level id, and runs `build_level.py` for the ones it
finds. Levels whose artwork has not been generated yet are skipped and
reported, so this is safe to re-run as images trickle in.

    python tool/build_all_levels.py --scenes C:\\temp\\findo\\scenes
    python tool/build_all_levels.py --scenes C:\\temp\\findo\\scenes --only 21-30
    python tool/build_all_levels.py --scenes C:\\temp\\findo\\scenes --rebuild

Name the scene files after the level id: `level_21.png`, `level_22.jpg`, and so
on. The ladder's crowd sizes and decoy counts are for the Gemini prompt in
docs/GEMINI_100_LEVELS.md; this script only uses the columns that affect the
build.

It rewrites `assets/images/maps/meta/index.json` at the end, from the levels
that actually exist on disk. It will refuse to write an index with a gap in it,
because the unlock chain runs on consecutive indexes and a hole in the middle
would strand every level after it.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LADDER = ROOT / 'tool/levels.csv'
META = ROOT / 'assets/images/maps/meta'
SCENE_SUFFIXES = ('.png', '.jpg', '.jpeg', '.webp')


def read_ladder() -> list[dict]:
    with LADDER.open(encoding='utf-8') as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        row['index'] = int(row['index'])
        row['height'] = int(row['height'])
        row['time'] = int(row['time'])
        row['spots'] = int(row['spots'])
    rows.sort(key=lambda r: r['index'])
    return rows


def parse_range(text: str) -> range:
    """`--only 21-30`, or `--only 44` for a single level."""
    if '-' in text:
        first, last = text.split('-', 1)
        return range(int(first), int(last) + 1)
    only = int(text)
    return range(only, only + 1)


def find_scene(folder: Path, level_id: str) -> Path | None:
    for suffix in SCENE_SUFFIXES:
        candidate = folder / f'{level_id}{suffix}'
        if candidate.exists():
            return candidate
    return None


def write_index() -> None:
    """Rewrites the manifest as the longest run of levels starting at one.

    `build_level.py` adds each level to the index as it writes it, so building
    level 21 before level 20 exists leaves a hole -- and the unlock chain runs
    on consecutive indexes, so a hole strands every level after it and the
    catalogue test fails. Rather than refuse and leave that behind, this keeps
    the manifest to the part that actually plays and says what it held back.
    The artwork stays on disk and is picked up the moment the gap is filled.
    """
    on_disk = sorted(
        (json.loads(path.read_text())['index'], path.stem)
        for path in META.glob('level_*.json')
    )

    playable, expected = [], 1
    for index, name in on_disk:
        if index != expected:
            break
        playable.append((index, name))
        expected += 1

    (META / 'index.json').write_text(
        json.dumps({'levels': [name for _, name in playable]}, indent=2) + '\n'
    )
    print(f'\nindex.json now lists {len(playable)} levels')

    held = [name for index, name in on_disk if index > len(playable)]
    if held:
        print(f'held back, because level {len(playable) + 1} does not exist '
              f'yet: {", ".join(held)}')
        print('Their maps and metadata are on disk and will be listed as soon '
              'as the gap is filled.')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenes', required=True,
                        help='folder holding the scenes, named level_NN.png')
    parser.add_argument('--only', help='a level or a range, e.g. 21-30')
    parser.add_argument('--rebuild', action='store_true',
                        help='rebuild levels that are already registered')
    parser.add_argument('--dry-run', action='store_true',
                        help='say what would be built, build nothing')
    args = parser.parse_args()

    folder = Path(args.scenes).expanduser()
    if not folder.is_dir():
        print(f'no such folder: {folder}', file=sys.stderr)
        return 1

    wanted = parse_range(args.only) if args.only else None

    built, skipped, waiting, failed = [], [], [], []
    for row in read_ladder():
        if wanted is not None and row['index'] not in wanted:
            continue

        registered = (META / f"{row['id']}.json").exists()
        scene = find_scene(folder, row['id'])

        if scene is None:
            (skipped if registered else waiting).append(row)
            continue
        if registered and not args.rebuild:
            skipped.append(row)
            continue

        # Flushed, because build_level.py writes straight to the console while
        # this process buffers. Without it every heading lands after the output
        # it introduces, and across eighty levels you cannot tell whose lines
        # you are reading.
        print(f"\n=== {row['id']}  {row['name_key']}  "
              f"{row['height']}px  {row['time']}s ===", flush=True)
        if args.dry_run:
            print(f'  would build from {scene.name}')
            built.append(row)
            continue

        result = subprocess.run(
            [sys.executable, str(ROOT / 'tool/build_level.py'), 'level',
             '--scene', str(scene),
             '--id', row['id'],
             '--index', str(row['index']),
             '--name-key', row['name_key'],
             '--height', str(row['height']),
             '--time', str(row['time']),
             '--spots', str(row['spots']),
             '--tint', row['tint']],
            cwd=str(ROOT),
        )
        (built if result.returncode == 0 else failed).append(row)

    print('\n' + '-' * 62)
    print(f"built {len(built)}, already registered {len(skipped)}, "
          f"waiting for artwork {len(waiting)}, failed {len(failed)}")

    if waiting:
        names = ', '.join(row['id'] for row in waiting[:12])
        more = '' if len(waiting) <= 12 else f' and {len(waiting) - 12} more'
        print(f"\nno scene file yet for: {names}{more}")
        print(f"drop them in {folder} named after the level id, then re-run")

    if failed:
        print('\nfailed: ' + ', '.join(row['id'] for row in failed),
              file=sys.stderr)

    if args.dry_run:
        return 1 if failed else 0

    if built:
        write_index()
        print('\nCheck store/previews/level_NN_spot*.png before trusting these '
              '-- one crop per hiding place, so you can see she is among people '
              'rather than stranded somewhere nobody would stand.')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
