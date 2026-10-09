# Cameo

A minimal macOS menu bar app that puts a character video with an alpha channel on your desktop: always on top, drag it anywhere, clicks pass through its transparent pixels.

- macOS 14+, Apple silicon or Intel
- Formats: HEVC with Alpha (`.mov`), ProRes 4444 (`.mov`)

## Build

Command Line Tools are enough (no Xcode project):

```bash
scripts/build.sh
open build/Cameo.app
```

Use: click the figure-in-a-screen icon in the menu bar, add a video with `+` (or drop it onto the popover, or "Open With → Cameo" in Finder), pick a character, drag the figure anywhere. Right-click a card to delete it.

Release zip: `scripts/package.sh` → `build/Cameo-<version>.zip` (ad-hoc signed; on first launch right-click → Open).

## Make a compatible video

```bash
# any source with alpha → HEVC with Alpha (macOS, VideoToolbox)
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or the built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

## License

MIT
