#!/usr/bin/env python3
"""Writes a release's notes: its entries from gallery/changelog.json (English), then the
install steps in .github/release-notes.md. Used by the release workflow:
scripts/release_notes.py 0.6.0 > notes.md"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LABELS = {"new": "New", "improved": "Better", "fixed": "Fixed"}


def main() -> None:
    version = sys.argv[1].removeprefix("v")
    releases = json.loads((ROOT / "gallery/changelog.json").read_text())
    release = next((r for r in releases if r["version"] == version), None)
    lines = []
    if release:
        lines += [f"- **{LABELS.get(item['kind'], 'New')}:** {item['en']}" for item in release["items"]]
        lines.append("")
    else:
        print(f"warning: {version} is not in gallery/changelog.json", file=sys.stderr)
    lines.append((ROOT / ".github/release-notes.md").read_text().strip())
    print("\n".join(lines))


if __name__ == "__main__":
    main()
