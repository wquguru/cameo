<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cameo icon">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  A tiny macOS menu bar app that puts a transparent character video on your desktop.
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo plays a looping video with an alpha channel as a free-floating figure that stays on top of every window and Space. Drag the figure anywhere; clicks on its transparent pixels pass straight through to whatever is underneath.

## Features

- **A cat comes built in** — Chaofei, a silver tabby British Shorthair drawn in code after the author's own cat, wanders along the bottom of your screen: it walks, sits, lies down and dozes off, stands and rolls. Click it to make it roll, drag it to pick it up, or pin an action from the popover.
- **Truly transparent** — only the visible pixels of the figure catch the mouse; everything else is click-through.
- **Always on top** — floats above all windows on every Space.
- **Native formats** — HEVC with Alpha and ProRes 4444 (`.mov`), decoded by AVFoundation. No FFmpeg, no bundled codecs.
- **Light on resources** — pauses when hidden by a full-screen app or while the screen sleeps, and caps at 30 fps on battery.
- **Minimal** — a menu bar popover and a plain character library. No settings, no dependencies.

## Requirements

- macOS 14 Sonoma or later (Apple silicon or Intel)
- Building from source: Xcode Command Line Tools (`xcode-select --install`)

## Installation

### Download

Download **`Cameo-<version>-macOS-Universal.dmg`** from [Releases](https://github.com/wquguru/cameo/releases) — one installer for Apple silicon and Intel Macs running macOS 14 or later. Open it and drag **Cameo** into **Applications**. A `.zip` of the bare app and `checksums.txt` (SHA-256) sit next to it.

The app is ad-hoc signed (not notarized). On first launch macOS blocks it: open **System Settings › Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Cameo.app`.

### Updates and languages

Cameo checks for updates daily and updates itself from the popover. It speaks 11 languages and follows your Mac's; pick another under **Language** in the popover.

### Build from source

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

### Uninstall

Turn off **Open at Login** in the popover, quit Cameo and move it to the Trash. Your imported characters and settings stay behind until you delete `~/Library/Application Support/Cameo` and run `defaults delete io.github.wquguru.cameo`.

## Usage

1. Click the Cameo icon (a figure peeking out of a screen) in the menu bar.
2. Add a video with **+**, by dropping it onto the popover, or via **Open With → Cameo** in Finder.
3. Pick a character and drag the figure wherever you like.

Menu bar too full and the icon hidden behind the notch? Open Cameo again (Spotlight or Launchpad), or right-click the figure, to get the same popover.

While the figure is hidden, Cameo also stays in the Dock: click it for the popover, or drop a video on it to add one.

With more than a handful of characters, open the library to search, rename or remove them. Imported videos are copied to `~/Library/Application Support/Cameo/Characters`.

## Characters

### Gallery

Browse free characters at **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** and click **Add to Cameo**: the app downloads the character and switches to it (via a `cameo://add?url=…` link).

### Make a character

A character is one looping `.mov` with alpha (HEVC with Alpha or ProRes 4444). The easiest route is to let your coding agent make it with a bundled skill:

| You have | Skill |
| --- | --- |
| A green-screen clip, or a video with alpha | [`cameo-from-video`](skills/cameo-from-video/SKILL.md) |
| Only a description (needs an OpenRouter API key) | [`cameo-image-loop`](skills/cameo-image-loop/SKILL.md) |

```bash
npx skills add wquguru/cameo --skill cameo-from-video  # from a video
npx skills add wquguru/cameo --skill cameo-image-loop  # from a description
```

Then ask, e.g. *"Turn ~/Downloads/dance.mp4 into a Cameo character"* or *"Make a Cameo character: a woman in a yellow sundress, sitting, waving"*. It checks the result and adds it to Cameo.

Made one you like? [Upload it to the gallery](https://wquguru.github.io/cameo/#submit) for review.

## Development

```bash
swift build                        # debug build
scripts/build.sh                   # release app bundle in build/Cameo.app
swift run CameoSample sample.mov   # a test clip with alpha
```

See [AGENTS.md](AGENTS.md) for the project layout, packaging and releases.

## Contributing

Issues and pull requests are welcome. Cameo is deliberately small, so please open an issue to discuss new features before adding UI.

## License

[Apache License 2.0](LICENSE)
