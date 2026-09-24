"""Pushes the store page -- the words and the screenshots -- to Play.

The text comes from `store/LISTING.md`, which is where it is written and
reviewed, so the page and the file cannot drift apart. The screenshots come
from `store/screenshots/<language>/`, captured from a real run of the build.

    python tool/update_listing.py            # say what would change
    python tool/update_listing.py --write    # change it

Play still calls Hebrew `iw-IL`, the code it had before `he` existed, and a
listing written to `he-IL` would quietly create a second, empty translation
nobody sees.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = "com.findo.game"
KEY = r"C:\AI\findo-publisher.json"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# The folder each store language takes its screenshots from.
LANGUAGES = {"en-US": "en", "iw-IL": "he"}


def blocks() -> dict[str, dict[str, str]]:
    """The listing text, read out of the document it is written in."""
    text = (ROOT / "store/LISTING.md").read_text(encoding="utf-8")
    found = re.findall(r"### ([^\n]+)\n\n```\n(.*?)\n```", text, re.S)
    order = ["en-US", "iw-IL"]
    out: dict[str, dict[str, str]] = {}
    for title, body in found:
        which = order[0] if len(out.get(order[0], {})) < 3 else order[1]
        field = ("title" if title.startswith("App name")
                 else "shortDescription" if title.startswith("Short")
                 else "fullDescription" if title.startswith("Full")
                 else None)
        if field:
            out.setdefault(which, {})[field] = body
    return out


def service():
    credentials = service_account.Credentials.from_service_account_file(
        KEY, scopes=[SCOPE])
    return build("androidpublisher", "v3", credentials=credentials,
                 cache_discovery=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="send it; without this nothing is changed")
    args = parser.parse_args()

    text = blocks()
    api = service()
    edits = api.edits()
    edit = edits.insert(body={}, packageName=PACKAGE).execute()
    edit_id = edit["id"]
    committed = False
    try:
        for language, folder in LANGUAGES.items():
            wanted = text[language]
            current = edits.listings().get(
                packageName=PACKAGE, editId=edit_id, language=language).execute()
            print(f"\n  {language}")
            for field in ("title", "shortDescription", "fullDescription"):
                was, now = len(current.get(field, "")), len(wanted[field])
                mark = "same" if current.get(field) == wanted[field] else f"{was} -> {now}"
                print(f"    {field:<18} {mark}")

            shots = sorted((ROOT / "store/screenshots" / folder).glob("*.png"))
            on_record = edits.images().list(
                packageName=PACKAGE, editId=edit_id, language=language,
                imageType="phoneScreenshots").execute().get("images", [])
            print(f"    screenshots        {len(on_record)} -> {len(shots)}")

            if not args.write:
                continue

            edits.listings().update(
                packageName=PACKAGE, editId=edit_id, language=language,
                body=wanted).execute()
            edits.images().deleteall(
                packageName=PACKAGE, editId=edit_id, language=language,
                imageType="phoneScreenshots").execute()
            for shot in shots:
                edits.images().upload(
                    packageName=PACKAGE, editId=edit_id, language=language,
                    imageType="phoneScreenshots",
                    media_body=MediaFileUpload(str(shot), mimetype="image/png"),
                ).execute()
                print(f"      uploaded {shot.name}")

        if args.write:
            edits.commit(packageName=PACKAGE, editId=edit_id).execute()
            committed = True
            print("\n  the store page is updated.")
        else:
            print("\n  nothing was changed. Add --write.")
    finally:
        if not committed:
            edits.delete(packageName=PACKAGE, editId=edit_id).execute()


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
