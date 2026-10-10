#!/usr/bin/env python3
"""Builds the gallery's share pages from gallery/characters.json: for each character,
gallery/c/<id>/index.html (scripts/gallery-character.html, with its own Open Graph tags and
structured data, since link previews never run the gallery's script), gallery/og/<id>.png
(design/og-character.html, rendered by headless Google Chrome) and posters/<id>.webp (cwebp),
plus gallery/sitemap.xml. All of it is build output and stays out of git.

--site (the pages workflow only) also writes plain character links and an ItemList into
gallery/index.html, for crawlers that don't run its script; don't commit that change.

Usage: python3 scripts/gallery_pages.py [--no-images] [--site]
"""

import hashlib
import html
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
GALLERY = ROOT / "gallery"
SITE = "https://wquguru.github.io/cameo"
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
CATEGORIES = {"animal": "Animal", "person": "Person", "other": "Other"}
LICENSES = {"CC BY 4.0": "https://creativecommons.org/licenses/by/4.0/"}
MORE = 4


def fill(template, fields):
    """Replaces {{key}}; values are inserted as given, so escape them first."""
    return re.sub(r"\{\{(\w+)\}\}", lambda m: str(fields[m.group(1)]), template)


def esc(value):
    return html.escape(str(value), quote=True)


def ld(data):
    """JSON-LD that is safe inside <script>."""
    return json.dumps(data, ensure_ascii=False, indent=1).replace("</", "<\\/")


def seconds(c):
    d = c.get("duration")
    return f"{max(1, int(d + 0.5))} s" if d else "—"


def size(c):
    b = c.get("bytes")
    if not b:
        return "—"
    return f"{-(-b // 1000)} KB" if b < 1e6 else f"{b / 1e6:.1f} MB"


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24]) if head[:8] == b"\x89PNG\r\n\x1a\n" else (480, 480)


def x_handle(c):
    m = re.fullmatch(r"https://(?:x|twitter)\.com/(\w{1,15})", c.get("authorURL", ""))
    return f"@{m.group(1)}" if m else ""


def author_html(c):
    if c.get("authorURL", "").startswith("https://"):
        return f'<a href="{esc(c["authorURL"])}">{esc(c["author"])}</a>'
    return esc(c["author"])


def label(c, names):
    """The name, plus the author when another character has the same name."""
    return f"{c['name']} by {c['author']}" if names[c["name"].casefold()] > 1 else c["name"]


def webp(c, images):
    """posters/<id>.webp beside the .png; the pages fall back to the .png without it."""
    png = GALLERY / c["poster"]
    out = png.with_suffix(".webp")
    if images and shutil.which("cwebp"):
        subprocess.run(["cwebp", "-quiet", "-q", "82", "-alpha_q", "90", str(png), "-o", str(out)], check=True)
    return out.exists()


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


def poster_src(c, depth):
    """The poster path from a page `depth` folders below the gallery, .webp when built."""
    path = c["poster"][:-4] + ".webp" if c.get("_webp") and c["poster"].endswith(".png") else c["poster"]
    return "../" * depth + path


def mini(c):
    category = c.get("category")
    kind = f'<span data-t="{esc(category)}">{esc(CATEGORIES[category])}</span> · ' if category in CATEGORIES else ""
    return (f'      <a class="mini" href="../{esc(c["id"])}/">'
            f'<span class="thumb"><img src="{esc(poster_src(c, 2))}" alt="" loading="lazy"></span>'
            f'<span><strong>{esc(c["name"])}</strong><small>{kind}{esc(c["author"])}</small></span></a>')


def structured(c, url, description, og_image):
    video = {
        "@type": "VideoObject",
        "name": f"{c['name']}, a Cameo character",
        "description": description,
        "thumbnailUrl": [og_image, f"{SITE}/{c['poster']}"],
        "contentUrl": c["video"],
        "encodingFormat": "video/quicktime",
        "url": url,
        "creator": {"@type": "Person", "name": c["author"], **({"url": c["authorURL"]} if c.get("authorURL") else {})},
        "isPartOf": {"@type": "WebSite", "name": "Cameo", "url": f"{SITE}/"},
    }
    if c.get("added"):
        video["uploadDate"] = c["added"]
    if c.get("duration"):
        video["duration"] = f"PT{max(1, int(c['duration'] + 0.5))}S"
    if c.get("license", "CC BY 4.0") in LICENSES:
        video["license"] = LICENSES[c.get("license", "CC BY 4.0")]
    crumbs = {
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Characters", "item": f"{SITE}/"},
            {"@type": "ListItem", "position": 2, "name": c["name"], "item": url},
        ],
    }
    return ld({"@context": "https://schema.org", "@graph": [video, crumbs]})


def render_page(c, others, version, names):
    url = f"{SITE}/c/{c['id']}/"
    add = f"cameo://add?url={quote(c['video'], safe='')}&name={quote(c['name'], safe='')}"
    x = f"https://x.com/intent/post?text={quote(c['name'] + ' · Cameo', safe='')}&url={quote(url, safe='')}"
    category = c.get("category") if c.get("category") in CATEGORIES else "other"
    shown = label(c, names)
    description = (f"Put {c['name']} on your Mac desktop: a free, transparent {CATEGORIES[category].lower()} "
                   f"character by {c['author']} that floats above your windows, for Cameo.")
    og_image = f"{SITE}/og/{c['id']}.png?v={version}" if version else f"{SITE}/og.png"
    width, height = png_size(GALLERY / c["poster"])
    fields = {
        "title": esc(f"{shown}: a free transparent desktop character for Mac · Cameo"),
        "og_title": esc(f"{shown} · Cameo character"),
        "name": esc(c["name"]),
        "description": esc(description),
        "url": esc(url),
        "og_image": esc(og_image),
        "twitter": esc(x_handle(c) or "@wquguru"),
        "jsonld": structured(c, url, description, og_image),
        "poster": esc(f"../../{c['poster']}"),
        "poster_webp": esc(poster_src(c, 2)),
        "poster_w": width,
        "poster_h": height,
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


def sitemap(characters):
    newest = max((c.get("added", "") for c in characters), default="")
    rows = [(f"{SITE}/", newest)] + [(f"{SITE}/c/{c['id']}/", c.get("added", "")) for c in characters]
    body = "".join(f"  <url><loc>{esc(loc)}</loc>{f'<lastmod>{day}</lastmod>' if day else ''}</url>\n" for loc, day in rows)
    (GALLERY / "sitemap.xml").write_text(
        f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{body}</urlset>\n')


def prerender_index(characters):
    """Static character links in the grid (the script replaces them) and an ItemList."""
    page = GALLERY / "index.html"
    text = page.read_text()
    cards = "".join(
        f'\n      <article class="card"><a class="stage" style="display: block" href="c/{esc(c["id"])}/">'
        f'<img src="{esc(poster_src(c, 0))}" alt="{esc(c["name"])}" loading="lazy"></a>'
        f'<div class="meta"><div><div class="name"><a href="c/{esc(c["id"])}/">{esc(c["name"])}</a></div>'
        f'<div class="by">by {esc(c["author"])}</div></div></div></article>' for c in characters)
    grid = '<div class="grid" id="grid"></div>'
    if grid not in text:
        sys.exit("gallery/index.html has no empty #grid to fill")
    text = text.replace(grid, f'<div class="grid" id="grid">{cards}\n    </div>')
    items = ld({"@context": "https://schema.org", "@type": "ItemList", "name": "Cameo characters",
                "itemListElement": [{"@type": "ListItem", "position": i + 1, "url": f"{SITE}/c/{c['id']}/", "name": c["name"]}
                                    for i, c in enumerate(characters)]})
    text = text.replace("</head>", f'<script type="application/ld+json">\n{items}\n</script>\n</head>', 1)
    page.write_text(text)


def main():
    args = sys.argv[1:]
    images = "--no-images" not in args
    if images and not Path(CHROME).exists():
        sys.exit(f"Google Chrome not found at {CHROME}; set CHROME or pass --no-images")
    if images and not shutil.which("cwebp"):
        print("cwebp not found: the pages use the .png posters", file=sys.stderr)
    characters = [c for c in json.loads((GALLERY / "characters.json").read_text())
                  if re.fullmatch(r"[a-z0-9-]+", c.get("id", ""))]
    names = Counter(c["name"].casefold() for c in characters)
    for folder in ("c", "og"):
        shutil.rmtree(GALLERY / folder, ignore_errors=True)
    (GALLERY / "og").mkdir()
    for c in characters:
        c["_webp"] = webp(c, images)
    with tempfile.TemporaryDirectory() as tmp:
        for i, c in enumerate(characters):
            version = render_card(c, CHROME, Path(tmp)) if images else ""
            others = (characters[i + 1:] + characters[:i])[:MORE]
            render_page(c, others, version, names)
            print(f"c/{c['id']}/")
    sitemap(characters)
    if "--site" in args:
        prerender_index(characters)


if __name__ == "__main__":
    main()
