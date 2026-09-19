"""Uploads the release bundle to Google Play.

Reading is free; uploading is not. Run it with no arguments and it only looks:
it says what the store currently has on each track and what this machine has
built, and changes nothing. Adding --upload is what sends the bundle, and it
asks first unless --yes is given.

    python tool/upload_aab.py                     # look, change nothing
    python tool/upload_aab.py --upload            # to internal testing
    python tool/upload_aab.py --upload --track production

The key is a credential for the whole developer account. It is read from
FINDO_PLAY_KEY, or from the default path below, and never from the repo.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = "com.findo.game"
DEFAULT_KEY = r"C:\AI\findo-publisher.json"
DEFAULT_BUNDLE = ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Anything beyond internal testing reaches people who did not ask to be
# testers, so those tracks have to be named out loud.
TRACKS = ("internal", "alpha", "beta", "production")


def local_version():
    """The version in pubspec.yaml, as (name, code)."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)\s*$", text, re.MULTILINE)
    if not match:
        raise SystemExit("no version in pubspec.yaml")
    return match.group(1), int(match.group(2))


def service(key_path):
    if not Path(key_path).is_file():
        raise SystemExit(
            f"no key at {key_path}.\n"
            "Point FINDO_PLAY_KEY at the service account's JSON file."
        )
    credentials = service_account.Credentials.from_service_account_file(
        key_path, scopes=[SCOPE]
    )
    return build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)


def show(api, name, code):
    """What the store has, and what this machine built. Changes nothing."""
    edits = api.edits()
    edit = edits.insert(body={}, packageName=PACKAGE).execute()
    try:
        tracks = edits.tracks().list(
            packageName=PACKAGE, editId=edit["id"]
        ).execute().get("tracks", [])
        print(f"  {'track':<12} {'status':<12} version codes")
        for track in tracks:
            for release in track.get("releases", []):
                print(
                    f"  {track['track']:<12} {release.get('status', '?'):<12} "
                    f"{', '.join(str(v) for v in release.get('versionCodes', [])) or '-'}"
                )
        if not tracks:
            print("  (no releases on any track yet)")
    finally:
        # Nothing was changed, and an abandoned edit leaves no trace.
        edits.delete(packageName=PACKAGE, editId=edit["id"]).execute()
    print(f"\n  built here   {name}+{code}")


def upload(api, path, track, code, notes, draft):
    edits = api.edits()
    edit = edits.insert(body={}, packageName=PACKAGE).execute()
    edit_id = edit["id"]
    print(f"  uploading {path.name} ({path.stat().st_size / 1048576:.1f} MB)...")
    bundle = edits.bundles().upload(
        packageName=PACKAGE,
        editId=edit_id,
        media_body=MediaFileUpload(str(path), mimetype="application/octet-stream",
                                   resumable=True),
    ).execute()
    uploaded = bundle["versionCode"]
    print(f"  accepted as version code {uploaded}")
    if uploaded != code:
        print(f"  note: pubspec says {code}; the store read {uploaded}")

    release = {
        "name": f"{local_version()[0]} ({uploaded})",
        "versionCodes": [str(uploaded)],
        "status": "draft" if draft else "completed",
    }
    if notes:
        hebrew, english = notes
        release["releaseNotes"] = [
            {"language": "he-IL", "text": hebrew},
            {"language": "en-US", "text": english or hebrew},
        ]
    edits.tracks().update(
        packageName=PACKAGE,
        editId=edit_id,
        track=track,
        body={"track": track, "releases": [release]},
    ).execute()
    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print(f"  released to {track} as {release['status']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upload", action="store_true",
                        help="actually send the bundle; without it, nothing is changed")
    parser.add_argument("--track", default="internal", choices=TRACKS)
    parser.add_argument("--bundle", default=str(DEFAULT_BUNDLE))
    parser.add_argument("--notes", default="", help="release notes, in Hebrew")
    parser.add_argument("--notes-en", default="", dest="notes_en",
                        help="the same notes in English; falls back to --notes")
    parser.add_argument("--draft", action="store_true",
                        help="upload without rolling out")
    parser.add_argument("--yes", action="store_true", help="skip the question")
    parser.add_argument("--key", default=os.environ.get("FINDO_PLAY_KEY", DEFAULT_KEY))
    args = parser.parse_args()

    api = service(args.key)
    name, code = local_version()

    print(f"\n  {PACKAGE}\n")
    show(api, name, code)

    if not args.upload:
        print("\n  nothing was changed. Add --upload to send the bundle.")
        return

    path = Path(args.bundle)
    if not path.is_file():
        raise SystemExit(f"no bundle at {path}. Build it first: python tool/release_aab.py")

    print(f"\n  about to put {path.name} on the {args.track} track"
          f"{' as a draft' if args.draft else ''}.")
    if args.track != "internal":
        print("  that track is not internal testing.")
    if not args.yes:
        if input("  type yes to go ahead: ").strip().lower() != "yes":
            raise SystemExit("  stopped; nothing was uploaded.")
    notes = (args.notes, args.notes_en) if args.notes else None
    upload(api, path, args.track, code, notes, args.draft)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001 - the message is for a person
        detail = getattr(error, "content", b"")
        if detail:
            try:
                detail = json.loads(detail)["error"]["message"]
            except Exception:  # noqa: BLE001
                detail = detail.decode("utf-8", "replace")
            print(f"\n  Play refused: {detail}", file=sys.stderr)
        else:
            print(f"\n  {error}", file=sys.stderr)
        raise SystemExit(1)
