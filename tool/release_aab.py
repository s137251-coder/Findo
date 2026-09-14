"""Bumps the version code, builds the release bundle, and checks what came out.

    python tool/release_aab.py                 bump, build, verify
    python tool/release_aab.py --to 42         bump to a specific code
    python tool/release_aab.py --no-build      bump only

Play consumes a version code the moment it accepts an upload and never returns
it -- including for a release that is created and then discarded. So every
bundle gets its own code, and the bump happens here rather than by remembering
to edit `pubspec.yaml`, because forgetting it is only discovered after a four
minute build and a rejected upload.

The verify step exists because "the build succeeded" has already been wrong
once in this project: an AAB built before a fix was nearly uploaded after it.
It reads the code back out of the compiled manifest rather than trusting the
pubspec it just wrote, and refuses to report success if the two disagree.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
BUNDLE = ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"

VERSION_LINE = re.compile(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", re.M)


def read_version() -> tuple[str, int]:
    match = VERSION_LINE.search(PUBSPEC.read_text(encoding="utf-8"))
    if not match:
        raise SystemExit("pubspec.yaml has no `version: x.y.z+n` line")
    return match.group(1), int(match.group(2))


def write_version(name: str, code: int) -> None:
    text = PUBSPEC.read_text(encoding="utf-8")
    PUBSPEC.write_text(
        VERSION_LINE.sub(f"version: {name}+{code}", text, count=1), encoding="utf-8"
    )


def build() -> None:
    print("building the app bundle, this takes a few minutes...")
    result = subprocess.run(
        ["flutter", "build", "appbundle", "--release"],
        cwd=ROOT,
        shell=os.name == "nt",
    )
    if result.returncode != 0:
        raise SystemExit(f"flutter build failed with {result.returncode}")


def bundle_version_code(bundle: zipfile.ZipFile) -> int | None:
    """Reads the code back out of the compiled manifest.

    The manifest is protobuf, not XML; the value sits just after the attribute
    name as a length-prefixed string.
    """
    raw = bundle.read("base/manifest/AndroidManifest.xml")
    at = raw.find(b"versionCode")
    if at < 0:
        return None
    match = re.search(rb"versionCode\x1a(.)([0-9]+)", raw[at:at + 24])
    return int(match.group(2)) if match else None


def verify(expected_code: int) -> None:
    if not BUNDLE.exists():
        raise SystemExit(f"no bundle at {BUNDLE}")

    with zipfile.ZipFile(BUNDLE) as bundle:
        broken = bundle.testzip()
        if broken is not None:
            raise SystemExit(f"bundle is corrupt at {broken}")

        found = bundle_version_code(bundle)
        if found != expected_code:
            raise SystemExit(
                f"bundle carries version code {found}, expected {expected_code}. "
                "It is stale -- the build did not pick up the bump."
            )

        names = bundle.namelist()
        index = next(x for x in names if x.endswith("maps/meta/index.json"))
        levels = len(json.loads(bundle.read(index))["levels"])
        maps = len([x for x in names if "assets/images/maps/level_" in x])
        sprite = any("targets/findo" in x for x in names)
        pools = {
            folder: len([x for x in names if f"/audio/{folder}/" in x])
            for folder in ("ok", "notok", "music")
        }
        signed = any(x.endswith((".RSA", ".DSA", ".EC")) for x in names)

    size_mb = BUNDLE.stat().st_size / 1024 / 1024
    print()
    print(f"  bundle       {BUNDLE}")
    print(f"  version      {read_version()[0]}+{expected_code}")
    print(f"  size         {size_mb:.1f} MB")
    print(f"  levels       {levels} in the manifest, {maps} maps packed")
    print(f"  character    {'present' if sprite else 'MISSING'}")
    print(f"  audio        ok {pools['ok']}, notok {pools['notok']}, music {pools['music']}")
    print(f"  signed       {'yes' if signed else 'NO -- check android/key.properties'}")

    problems = []
    if levels < 1:
        problems.append("the manifest lists no levels")
    if not sprite:
        problems.append("the character sprite is missing")
    if not signed:
        problems.append("the bundle is unsigned")
    if not pools["music"]:
        problems.append("no music shipped; the game falls back to the synth loop")
    if problems:
        raise SystemExit("\n".join("  problem: " + p for p in problems))
    print("\nready to upload.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--to", type=int, metavar="CODE",
                        help="set this version code instead of adding one")
    parser.add_argument("--no-build", action="store_true",
                        help="write the new version and stop")
    args = parser.parse_args()

    name, current = read_version()
    nxt = args.to if args.to is not None else current + 1
    if nxt <= current:
        raise SystemExit(
            f"version code must increase: {current} is already in pubspec.yaml"
        )

    write_version(name, nxt)
    print(f"version {name}+{current} -> {name}+{nxt}")
    if args.no_build:
        return
    build()
    verify(nxt)


if __name__ == "__main__":
    main()
