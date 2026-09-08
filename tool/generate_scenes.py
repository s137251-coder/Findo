"""Generate the level artwork through the Gemini API, and check what comes back.

Walks the scene catalogue in `tool/scenes.json`, asks the image model for each
scene that has no artwork yet, and saves it as `level_NN.png` ready for
`build_all_levels.py`. Safe to stop and re-run: it skips what is already on
disk, so an interrupted run costs nothing but the images it had already paid
for.

    set GEMINI_API_KEY=...
    python tool/generate_scenes.py --out C:\\temp\\findo\\scenes
    python tool/generate_scenes.py --out C:\\temp\\findo\\scenes --only 20-30
    python tool/generate_scenes.py --out C:\\temp\\findo\\scenes --dry-run

WHAT IT CAN AND CANNOT CHECK

Every image is checked for three failures that are mechanically visible: the
wrong shape, too few pixels to zoom into, and a crowd collapsed into a corner
of the frame. A level that fails them is retried rather than saved.

The crowd check is deliberately blunt. It fires when half the frame is empty of
people, not when a third is, because a third of the frame being sky or wall is
what the castle map legitimately looks like. It was calibrated against all
nineteen maps already in the game: none of them trips it, and a crowd squeezed
into one quadrant does.

It cannot see the two failures that actually break a level: text baked into a
sign, and a figure wearing all three of Findo's signatures at once. Those need
eyes. Look at `store/previews/level_NN_spot*.png` after building, every time.

You are billed per image by Google, including for images this rejects and
retries. Check the current price before setting it going on eighty of them.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import statistics
import sys
import time
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_level import people_mask  # noqa: E402  same folder, shared heuristic

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / 'tool/scenes.json'

# Override with --model. Image model names change; if this one is rejected,
# check which image models your key can reach in Google AI Studio.
DEFAULT_MODEL = 'gemini-2.5-flash-image'
ENDPOINT = ('https://generativelanguage.googleapis.com/v1beta/'
            'models/{model}:generateContent')

MIN_SIDE = 2048          # build_level.py refuses anything smaller
SQUARE_TOLERANCE = 0.02  # 2% off 1:1 is a crop, not a rounding difference


def load_catalogue() -> dict:
    data = json.loads(CATALOGUE.read_text(encoding='utf-8'))
    return data


def build_prompt(catalogue: dict, index: int) -> str:
    """The shared rules, this level's band, and this level's scene."""
    entry = catalogue['scenes'][str(index)]
    band = catalogue['bands'][str(entry['band'])]
    return (
        f"{catalogue['rules']}\n\n"
        f"THIS IMAGE\n{band}\n\n"
        f"{entry['scene']}\n\n"
        "Return exactly one image and no text."
    )


def request_image(prompt: str, model: str, api_key: str, timeout: int):
    """Returns (image, error). Exactly one of them is None."""
    try:
        response = requests.post(
            ENDPOINT.format(model=model),
            params={'key': api_key},
            json={
                'contents': [{'parts': [{'text': prompt}]}],
                'generationConfig': {'responseModalities': ['IMAGE']},
            },
            timeout=timeout,
        )
    except requests.RequestException as error:
        return None, f'request failed: {error}'

    if response.status_code != 200:
        return None, f'HTTP {response.status_code}: {response.text[:400]}'

    try:
        parts = response.json()['candidates'][0]['content']['parts']
    except (KeyError, IndexError, ValueError):
        return None, f'unexpected response shape: {response.text[:400]}'

    for part in parts:
        # REST returns camelCase; the SDKs use snake_case. Accept either.
        blob = part.get('inlineData') or part.get('inline_data')
        if blob and blob.get('data'):
            raw = base64.b64decode(blob['data'])
            return Image.open(BytesIO(raw)).convert('RGB'), None

    return None, 'the reply carried no image'


def inspect(image: Image.Image) -> tuple[list[str], list[str]]:
    """Returns (problems, notes). A non-empty problems list means reject."""
    problems, notes = [], []
    width, height = image.size

    if abs(width - height) / max(width, height) > SQUARE_TOLERANCE:
        problems.append(f'not square: {width}x{height}')
    if min(width, height) < MIN_SIDE:
        problems.append(f'{width}x{height} is under the {MIN_SIDE} px the '
                        f'maps need to stay sharp at full zoom')

    # Is the crowd spread, or bunched into one part of the frame? Measured on
    # isolated skin tones, the same way build_level.py finds hiding places.
    mask = people_mask(image)
    rows, columns = mask.shape
    cells = []
    for gy in range(4):
        for gx in range(4):
            cell = mask[gy * rows // 4:(gy + 1) * rows // 4,
                        gx * columns // 4:(gx + 1) * columns // 4]
            cells.append(float(cell.mean()))

    # Measured against a busy cell rather than the median. The median is the
    # wrong reference for the failure this is looking for: a crowd squeezed
    # into a quarter of the frame leaves most cells empty, which drags the
    # median to zero and makes the image look consistent with itself.
    reference = sorted(cells)[len(cells) * 3 // 4]
    if reference < 1e-5:
        # A night scene has few lit faces, so there is nothing to measure. Say
        # so rather than reject: a false rejection costs another paid image.
        notes.append('crowd spread not assessable, too few visible skin tones')
    else:
        empty = sum(1 for value in cells if value < reference * 0.15)
        # Eight of sixteen is the bar because real scenes legitimately have
        # empty ground: the castle map's sky and walls leave five cells nearly
        # bare and it is a perfectly good level. Half the frame with nobody in
        # it is a different thing.
        if empty >= 8:
            problems.append(f'{empty} of 16 areas are nearly empty of people; '
                            f'the crowd is bunched rather than filling the frame')

    return problems, notes


def parse_range(text: str) -> range:
    if '-' in text:
        first, last = text.split('-', 1)
        return range(int(first), int(last) + 1)
    return range(int(text), int(text) + 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, help='folder to save into')
    parser.add_argument('--only', help='a level or a range, e.g. 20-30')
    parser.add_argument('--model', default=DEFAULT_MODEL)
    parser.add_argument('--retries', type=int, default=3,
                        help='attempts per level before giving up')
    parser.add_argument('--delay', type=float, default=2.0,
                        help='seconds between calls')
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--redo', action='store_true',
                        help='regenerate levels that already have artwork')
    parser.add_argument('--dry-run', action='store_true',
                        help='print the first prompt and stop, calling nothing')
    args = parser.parse_args()

    catalogue = load_catalogue()
    wanted = parse_range(args.only) if args.only else range(20, 101)
    todo = [i for i in sorted(int(k) for k in catalogue['scenes']) if i in wanted]

    if args.dry_run:
        print(build_prompt(catalogue, todo[0]))
        count = f'{len(todo)} levels are' if len(todo) != 1 else '1 level is'
        print(f'\n--- that is level {todo[0]}. '
              f'{count} in range. Nothing was called. ---')
        return 0

    api_key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not api_key:
        print('set GEMINI_API_KEY (get one from Google AI Studio)',
              file=sys.stderr)
        return 1

    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)

    saved, skipped, failed = [], [], []
    log = []

    for index in todo:
        target = out / f'level_{index:02d}.png' if index < 100 \
            else out / 'level_100.png'
        if target.exists() and not args.redo:
            skipped.append(index)
            continue

        prompt = build_prompt(catalogue, index)
        print(f'\n=== level {index} ===', flush=True)

        for attempt in range(1, args.retries + 1):
            image, error = request_image(prompt, args.model, api_key, args.timeout)
            if error:
                print(f'  attempt {attempt}: {error}', flush=True)
                time.sleep(args.delay)
                continue

            problems, notes = inspect(image)
            for note in notes:
                print(f'  note: {note}')
            if problems:
                for problem in problems:
                    print(f'  attempt {attempt} rejected: {problem}', flush=True)
                time.sleep(args.delay)
                continue

            image.save(target, 'PNG')
            size_mb = target.stat().st_size / 1_048_576
            print(f'  saved {target.name}  {image.width}x{image.height}  '
                  f'{size_mb:.1f} MB', flush=True)
            saved.append(index)
            log.append({'level': index, 'status': 'saved',
                        'attempts': attempt, 'notes': notes})
            break
        else:
            print(f'  gave up after {args.retries} attempts', flush=True)
            failed.append(index)
            log.append({'level': index, 'status': 'failed',
                        'attempts': args.retries})

        time.sleep(args.delay)

    (out / 'generation_log.json').write_text(
        json.dumps(log, indent=2) + '\n', encoding='utf-8')

    print('\n' + '-' * 62)
    print(f'saved {len(saved)}, already had artwork {len(skipped)}, '
          f'failed {len(failed)}')
    if failed:
        print('failed: ' + ', '.join(str(i) for i in failed), file=sys.stderr)
    if saved:
        print('\nNow build them:')
        print(f'  python tool/build_all_levels.py --scenes {out}')
        print('\nThen look at store/previews/level_NN_spot*.png. This script '
              'cannot see text baked into a sign, or a figure wearing all '
              'three of her signatures, and both of those break a level.')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
