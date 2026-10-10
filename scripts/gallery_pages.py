#!/usr/bin/env python3
"""Builds the gallery's share pages from gallery/characters.json: for each character,
gallery/c/<id>/index.html (scripts/gallery-character.html, with its own Open Graph tags, since
link previews never run the gallery's script) and gallery/og/<id>.png (design/og-character.html,
rendered by headless Google Chrome). The pages workflow runs it before upload; both folders are
build output and stay out of git.

Usage: python3 scripts/gallery_pages.py [--no-images]
"""

import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
GALLERY = ROOT / "gallery"
SITE = "https://wquguru.github.io/cameo"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
CATEGORIES = {"animal": "Animal", "person": "Person", "other": "Other"}
MORE = 4


def fill(template, fields):
    """Replaces {{key}}; values are inserted as given, so escape them first."""
    return re.sub(r"\{\{(\w+)\}\}", lambda m: fields[m.group(1)], template)


def esc(value):
    return html.escape(str(value), quote=True)


def seconds(c):
    d = c.get("duration")
    return f"{max(1, int(d + 0.5))} s" if d else "—"


def size(c):
    b = c.get("bytes")
    if not b:
        return "—"
    return f"{-(-b // 1000)} KB" if b < 1e6 else f"{b / 1e6:.1f} MB"


def author_html(c):
    if c.get("authorURL", "").startswith("https://"):
        return f'<a href="{esc(c["authorURL"])}">{esc(c["author"])}</a>'
    return esc(c["author"])


def render_card(c, chrome, workdir):
    """Writes og/<id>.png and returns a short content hash for cache-busting its URL."""
    name = c["name"]
    fields = {
        "name": esc(name),
        "name_size": "120" if len(name) <= 8 else "96" if len(name) <= 12 else "72",
        "category": esc(CATEGORIES.get(c.get("category"), "Character")),
        "author": esc(c["author"]),
        "facts": esc(f" · {seconds(c)} loop") if c.get("duration") else "",
        "poster": (GALLERY / c["poster"]).as_uri(),
        "icon": (GALLERY / "icon.png").as_uri(),
    }
    page = workdir / f"{c['id']}.html"
    page.write_text(fill((ROOT / "design/og-character.html").read_text(), fields))
    out = GALLERY / "og" / f"{c['id']}.png"
    subprocess.run(
        [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--window-size=1200,630", f"--screenshot={out}", page.as_uri()],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return hashlib.sha256(out.read_bytes()).hexdigest()[:10]


def mini(c):
    category = c.get("category")
    label = f'<span data-t="{esc(category)}">{esc(CATEGORIES[category])}</span> · ' if category in CATEGORIES else ""
    return (f'      <a class="mini" href="../{esc(c["id"])}/">'
            f'<span class="thumb"><img src="../../{esc(c["poster"])}" alt="" loading="lazy"></span>'
            f'<span><strong>{esc(c["name"])}</strong><small>{label}{esc(c["author"])}</small></span></a>')


def render_page(c, others, version):
    url = f"{SITE}/c/{c['id']}/"
    add = f"cameo://add?url={quote(c['video'], safe='')}&name={quote(c['name'], safe='')}"
    x = f"https://x.com/intent/post?text={quote(c['name'] + ' · Cameo', safe='')}&url={quote(url, safe='')}"
    category = c.get("category") if c.get("category") in CATEGORIES else "other"
    fields = {
        "name": esc(c["name"]),
        "description": esc(f"Put {c['name']} on your Mac desktop: a transparent character by {c['author']} that floats above your windows. Free, for Cameo."),
        "url": esc(url),
        "og_image": esc(f"{SITE}/og/{c['id']}.png?v={version}" if version else f"{SITE}/og.png"),
        "poster": esc(f"../../{c['poster']}"),
        "video": esc(c["video"]),
        "category": category,
        "category_label": CATEGORIES[category],
        "author_html": author_html(c),
        "license": esc(c.get("license", "CC BY 4.0")),
        "duration": esc(seconds(c)),
        "size": esc(size(c)),
        "add_link": esc(add),
        "x_link": esc(x),
        "more_html": "\n".join(mini(o) for o in others),
    }
    out = GALLERY / "c" / c["id"] / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(fill((ROOT / "scripts/gallery-character.html").read_text(), fields))


def main():
    images = "--no-images" not in sys.argv[1:]
    if images and not Path(CHROME).exists():
        sys.exit(f"Google Chrome not found at {CHROME}; set CHROME or pass --no-images")
    characters = [c for c in json.loads((GALLERY / "characters.json").read_text())
                  if re.fullmatch(r"[a-z0-9-]+", c.get("id", ""))]
    for folder in ("c", "og"):
        shutil.rmtree(GALLERY / folder, ignore_errors=True)
    (GALLERY / "og").mkdir()
    with tempfile.TemporaryDirectory() as tmp:
        for i, c in enumerate(characters):
            version = render_card(c, CHROME, Path(tmp)) if images else ""
            others = (characters[i + 1:] + characters[:i])[:MORE]
            render_page(c, others, version)
            print(f"c/{c['id']}/")


if __name__ == "__main__":
    main()
