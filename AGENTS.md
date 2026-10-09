# AGENTS.md

Cameo is a minimal, open-source macOS menu bar app that puts a character video with an alpha channel on the desktop as a free-floating, always-on-top figure.

## Scope (deliberately small)

- One menu bar popover, no other windows. Its contents: show/hide switch, character thumbnails (select / add), size slider, launch at login, quit.
- One character = one looping video. There are no clips, manifests or per-character settings.
- Exception: the built-in cat 小银 (`Character.builtInCat`), drawn in code and always first in the list. It wanders on its own (walk, sit, lie down, stand, roll), rolls when clicked, dangles while dragged, and the popover shows action chips (自由 + the five actions) only while it is selected.
- Formats: HEVC with Alpha (.mov) and ProRes 4444 (.mov), both decoded natively by AVFoundation. No FFmpeg, WebM or packed alpha.
- Behaviour that is not a setting: pixels with alpha go to the figure (drag to move), transparent pixels pass clicks through; always on top on every Space; playback pauses during full-screen apps, on battery it caps at 30 fps, and it pauses while the screen is locked or asleep.
- When a feature request fits none of the above, push back before adding UI.

## Design

- Source of truth: `design/` (Design canvas files: `Main`, `Popover`, `Logo`, `Icon` `.dc.html`, open in a browser as reference only).
- Theme "stage spotlight": dark glass popover, accent spotlight amber `#FFB340`, stage `#161618`, figure ivory `#F5F1EA`. A selected character card is "lit" (beam + floor glow, ivory figure); unselected cards are dark with a grey figure.
- Built-in cat: a semi-realistic silver tabby British Shorthair modelled on the owner's cat, side view (`design/cat-side.svg`; earlier cartoon explorations in `design/Cats.dc.html`). Art lives in `CatArt.swift` as SVG path data in design units; `CatRig` turns a `CatPose` into per-part transforms (auto-grounded, mirrored when walking left); `CatBrain` picks actions and animates poses.
- Logo: a figure whose head pokes out of the top edge of a screen. The menu bar glyph is the template (monochrome) line version of it, drawn in code (`Glyph.swift`).

## Layout

- `Package.swift`: SwiftPM, macOS 14+, Swift 5 language mode.
- `Sources/Cameo`: the app (AppKit + SwiftUI for the popover, AVFoundation for playback).
- `Sources/CameoSample`: a CLI that writes a sample HEVC-alpha clip, used for manual testing.
- `Sources/CameoIcon`: a CLI that renders the app icon PNGs (CoreGraphics), used by the build script.
- `scripts/build.sh`: builds release binaries and assembles `build/Cameo.app` (Info.plist, icon, ad-hoc signature).

## Commands

```bash
swift build                      # debug build
scripts/build.sh                 # release .app in build/Cameo.app
open build/Cameo.app
swift run CameoSample out.mov    # write a sample HEVC-alpha clip
CAMEO_OPEN_POPOVER=1 build/Cameo.app/Contents/MacOS/Cameo   # launch with the popover open
.build/debug/Cameo --render-poses poses.png                  # contact sheet of the cat's poses
```

Only Command Line Tools are required (no Xcode project). Do not add an `.xcodeproj`.

## Conventions

- Keep files small and single-purpose; match existing naming and comment density.
- Main-thread UI code is `@MainActor`; no third-party dependencies.
- User data lives in `~/Library/Application Support/Cameo/Characters` (imported videos are copied there) and `UserDefaults` (`selectedID`, `scale`, `visible`, `origin`).
- Commit in coherent batches with a short imperative subject.
