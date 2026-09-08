"""Pulls the shared rules and the 81 scenes out of the prompt document.

The document stays the thing a person reads and pastes by hand. This is the
machine-readable copy of the same text, so the agent and the paste-it-yourself
route cannot drift apart.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / 'docs/GEMINI_ALL_SCENES_PROMPT.md'
OUT = ROOT / 'tool/scenes.json'

text = DOC.read_text(encoding='utf-8')

# The prompt itself is the one fenced block that contains the scene catalogue.
blocks = re.findall(r'```[a-z]*\n(.*?)\n```', text, re.S)
prompt = next(b for b in blocks if '=================== THE SCENES' in b)

rules, catalogue = prompt.split('=================== THE SCENES ===================')
rules = rules.strip()

bands = {}
scenes = {}
current = None

for chunk in re.split(r'\n\n(?=--- BAND |\d{1,3} [A-Z])', catalogue.strip()):
    chunk = chunk.strip()
    if chunk.startswith('--- BAND'):
        header = ' '.join(chunk.split())
        header = header.removeprefix('--- ').removesuffix(' ---')
        band = int(re.match(r'BAND (\d+)', header).group(1))
        current = band
        bands[band] = header
        continue
    match = re.match(r'^(\d{1,3}) ', chunk)
    if not match:
        continue
    index = int(match.group(1))
    scenes[index] = {
        'band': current,
        'scene': ' '.join(chunk.split()),
    }

missing = sorted(set(range(20, 101)) - set(scenes))
assert not missing, f'scenes missing from the document: {missing}'
assert all(s['band'] is not None for s in scenes.values()), 'a scene has no band'

OUT.write_text(
    json.dumps(
        {
            'source': 'docs/GEMINI_ALL_SCENES_PROMPT.md',
            'rules': rules,
            'bands': {str(k): v for k, v in sorted(bands.items())},
            'scenes': {str(k): v for k, v in sorted(scenes.items())},
        },
        ensure_ascii=False,
        indent=2,
    ) + '\n',
    encoding='utf-8',
)
print(f'wrote {OUT.relative_to(ROOT)}: {len(scenes)} scenes, {len(bands)} bands')
print(f'rules block: {len(rules)} chars')
for band, header in sorted(bands.items()):
    count = sum(1 for s in scenes.values() if s['band'] == band)
    print(f'  band {band}: {count} scenes')
