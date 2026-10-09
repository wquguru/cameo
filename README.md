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

<p align="center">
  <b>English</b> · <a href="README.zh-CN.md">简体中文</a>
</p>

---

Cameo plays a looping video with an alpha channel as a free-floating figure that stays on top of every window and Space. Drag the figure anywhere; clicks on its transparent pixels pass straight through to whatever is underneath.

## Features

- **A cat comes built in** — 小银, a silver tabby drawn in code, wanders along the bottom of your screen: it walks, sits, lies down and dozes off, stands and rolls. Click it to make it roll, drag it to pick it up, or pin an action from the popover.
- **Truly transparent** — only the visible pixels of the figure catch the mouse; everything else is click-through.
- **Always on top** — floats above all windows on every Space.
- **Native formats** — HEVC with Alpha and ProRes 4444 (`.mov`), decoded by AVFoundation. No FFmpeg, no bundled codecs.
- **Light on resources** — pauses when hidden by a full-screen app or while the screen sleeps, and caps at 30 fps on battery.
- **Minimal** — one menu bar popover: show/hide, characters, size, launch at login. No settings windows, no dependencies.

## Requirements

- macOS 14 Sonoma or later (Apple silicon or Intel)
- Building from source: Xcode Command Line Tools (`xcode-select --install`)

## Installation

### Download

Grab `Cameo-<version>.zip` from [Releases](https://github.com/wquguru/cameo/releases) (or from the latest [CI run](https://github.com/wquguru/cameo/actions/workflows/build.yml)), unzip, and move `Cameo.app` to `/Applications`.

The app is ad-hoc signed, so on first launch right-click it and choose **Open**.

### Build from source

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## Usage

1. Click the Cameo icon (a figure peeking out of a screen) in the menu bar.
2. Add a video with **+**, by dropping it onto the popover, or via **Open With → Cameo** in Finder.
3. Pick a character and drag the figure wherever you like.

Right-click a character card to delete it. Imported videos are copied to `~/Library/Application Support/Cameo/Characters`.

## Preparing a video

Cameo expects a `.mov` with an alpha channel. To convert an existing clip:

```bash
# FFmpeg, hardware HEVC with Alpha via VideoToolbox
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov

# or Apple's built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

Need a test clip? `swift run CameoSample sample.mov` writes one.

## Development

```bash
swift build               # debug build
scripts/build.sh          # release app bundle in build/Cameo.app
scripts/package.sh        # release zip in build/Cameo-<version>.zip
```

| Path | Purpose |
| --- | --- |
| `Sources/Cameo` | The app (AppKit, SwiftUI popover, AVFoundation playback) |
| `Sources/CameoSample` | CLI that writes a sample HEVC-alpha clip |
| `Sources/CameoIcon` | CLI that renders the app icon |
| `design/` | Design reference files (open in a browser) |

## Contributing

Issues and pull requests are welcome. Cameo is deliberately small, so please open an issue to discuss new features before adding UI. See [AGENTS.md](AGENTS.md) for scope and conventions.

## License

[Apache License 2.0](LICENSE)
