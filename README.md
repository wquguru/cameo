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

## Make a compatible video

```bash
# any source with alpha → HEVC with Alpha (macOS, VideoToolbox)
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or the built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

## License

MIT
