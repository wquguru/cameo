# AGENTS.md

Cameo is a minimal, open-source macOS menu bar app that puts a character video with an alpha channel on the desktop as a free-floating, always-on-top figure.

## Scope (deliberately small)

- One menu bar popover and one library window (plus the standard About panel). The popover: show/hide switch, the 7 most recently shown characters (select / add) with a gallery link and "All N…" opening the library, size slider, check for updates / install update, About, launch at login, language, quit.
- The library window (`LibraryView`, design/Library*.dc.html) is deliberately plain: a grid, most recently shown first, with search and +. Click shows a character, hover previews it, the context menu renames, reveals or trashes (with undo); drop videos to add. No sidebar, views, sorting, favourites or inspector. While it is open Cameo has a Dock icon and menus (`MainMenu`).
- One character = one looping video. There are no clips, manifests or per-character settings.
- Exception: the built-in cat Chaofei (`Character.builtInCat`), drawn in code and always first in the list. It wanders on its own (walk, sit, lie down, stand, roll), rolls when clicked, dangles while dragged, and the popover shows action chips (自由 + the five actions) only while it is selected.
- Formats: HEVC with Alpha (.mov) and ProRes 4444 (.mov), both decoded natively by AVFoundation. No FFmpeg, WebM or packed alpha.
- Behaviour that is not a setting: pixels with alpha go to the figure (drag to move), transparent pixels pass clicks through; always on top on every Space; playback pauses during full-screen apps, on battery it caps at 30 fps, and it pauses while the screen is locked or asleep.
- When a feature request fits none of the above, push back before adding UI.

## Design

- Source of truth: `design/` (Design canvas files: `Main`, `Popover`, `PopoverDark`, `Logo`, `Icon` `.dc.html`, open in a browser as reference only).
- The popover looks like a native menu: system appearance (light/dark) and accent colour, 13 pt system text, full-width separators, grey section headers, menu rows highlighted on hover (`MenuRow`).
- Theme "stage spotlight" lives only where the stage shows: accent spotlight amber `#FFB340`, stage `#161618`, figure ivory `#F5F1EA`. The selected character card is "lit" (dark stage, beam + floor glow, full-colour figure) in both appearances; unselected cards are system-grey tiles with a greyed figure. Amber also marks an available update (menu bar badge, dot in the popover).
- Built-in cat: a semi-realistic silver tabby British Shorthair modelled on the owner's cat, side view (`design/cat-side.svg`; earlier cartoon explorations in `design/Cats.dc.html`). Art lives in `CatArt.swift` as SVG path data in design units; `CatRig` turns a `CatPose` into per-part transforms (auto-grounded, mirrored when walking left); `CatBrain` picks actions and animates poses.
- Logo: a figure whose head pokes out of the top edge of a screen. The menu bar glyph is the template (monochrome) line version of it, drawn in code (`Glyph.swift`).

## Layout

- `Package.swift`: SwiftPM, macOS 14+, Swift 5 language mode.
- `Sources/Cameo`: the app (AppKit + SwiftUI for the popover, AVFoundation for playback).
- `Sources/CameoSample`: a CLI that writes a sample HEVC-alpha clip, used for manual testing.
- `Sources/CameoIcon`: a CLI that renders the app icon PNGs (CoreGraphics), used by the build script.
- `scripts/build.sh`: builds a universal (arm64 + x86_64, via `--triple` builds and `lipo`) `build/Cameo.app` (Info.plist, icon, ad-hoc signature). `ARCHS=arm64` builds one architecture for quick local runs.
- `scripts/package.sh`: the release artifacts `Cameo-<version>-macOS-Universal.dmg` / `.zip` and `checksums.txt`. The DMG background is drawn by the app (`Cameo --render-dmg-background out.png <scale>`, `DMGBackground.swift`), and the window layout is `Resources/dmg/DS_Store`, made by Finder via `scripts/dmg-template.sh` (Finder writes the macOS 26 `pBB0` background bookmark that third-party writers miss). The volume is always named `Cameo`. Change the window, icon positions or background path → rerun `scripts/dmg-template.sh` on a Mac and keep `DMGBackground.swift` in sync.
- `gallery/`: static character gallery (GitHub Pages, `pages` workflow). `characters.json` lists entries; videos live in the Cloudflare R2 bucket `cameo-characters`, served at `https://cameo.wqu.guru/characters/<id>.mov`; upload with wrangler (`wrangler login`), never with the broad OAuth token in CI — CI would need its own bucket-scoped R2 token. Publish with `scripts/gallery-add.sh` (category: animal, person or other, which becomes a tab; duration is read from the video). Its social card is `gallery/og.png`, rendered from `design/og-card.html` by `scripts/og-image.sh` (headless Chrome); rerun it after changing either. Its "Add to Cameo" buttons are `cameo://add?url=<https .mov>&name=<name>` links (`GalleryLink.swift`).
- Submissions: the issue form (`.github/ISSUE_TEMPLATE/character.yml`, label `character`) is handled by the `character` workflow: `scripts/character_submission.py check` replies with `scripts/character-check.swift`'s verdict (HEVC alpha/ProRes 4444, up to 10 s, ≤1080 px tall, <20 MB to match website uploads; the GitHub form itself caps attachments at 10 MB; label `needs-changes` when it fails); a maintainer adding `approved` runs `publish`, which uploads to R2 with a bucket-scoped token (secrets `R2_ACCESS_KEY_ID`/`R2_SECRET_ACCESS_KEY`, variable `R2_ACCOUNT_ID`) commits the gallery entry straight to main, starts the `pages` workflow (pushes made with the workflow token trigger nothing), posts a new "published" comment linking `?c=<id>` and closes the issue. The issue body is untrusted: parse it, never interpolate it into shell.
- Website uploads: `upload/` is a Cloudflare Worker (`cameo-upload.wqu.guru/submit`, deploy with `cd upload && npx wrangler deploy`). The gallery form checks the file in the browser, then POSTs it as the raw body with fields in `X-` headers. Abuse controls in order: kill switch `UPLOADS_OPEN`, best-effort per-IP burst limiter (`BURST`), ban list (`ban:<uploader id>` in KV; the id is in each website issue), Turnstile bound to action `upload` and `TURNSTILE_HOSTNAME`, daily quotas in KV (`DAILY_PER_IP`, `DAILY_TOTAL`, IPs only as `IP_SALT`ed hashes), a review-queue cap (`QUEUE_MAX_FILES`/`QUEUE_MAX_BYTES` over pending/ + submitted/), 20 MB files, SHA-256 duplicate rejection for 30 days. The body is streamed into `pending/` of the private bucket `cameo-uploads` (no public domain; lifecycle: pending 2 days, submitted 14 days), and re-checks the `moov` box (`upload/src/mov.js`, copied to `gallery/mov.js`; depth 32 = alpha). The `intake` workflow (started by the Worker after each upload via the `GITHUB_DISPATCH_TOKEN` secret, plus every 15 min as a fallback) runs `scripts/character_intake.py`: AVFoundation check, move to `submitted/`, open a `character` issue whose video is `r2:submitted/<id>.mov`; approving it publishes from there. Never point a public domain at `cameo-uploads`.
- `skills/cameo-character`: agent skill (installable with `npx skills add wquguru/cameo`) that turns green-screen or alpha clips into Cameo characters.

## Commands

```bash
swift build                      # debug build
scripts/build.sh                 # release .app in build/Cameo.app
open build/Cameo.app
swift run CameoSample out.mov    # write a sample HEVC-alpha clip
CAMEO_OPEN_POPOVER=1 build/Cameo.app/Contents/MacOS/Cameo   # launch with the popover open
CAMEO_OPEN_LIBRARY=1 CAMEO_DATA_DIR=/tmp/lib build/Cameo.app/Contents/MacOS/Cameo   # library window, on a throwaway character folder
.build/debug/Cameo --render-poses poses.png                  # contact sheet of the cat's poses
build/Cameo.app/Contents/MacOS/Cameo -AppleLanguages '(ja)'  # try another language for one run
```

Release: `scripts/release.sh <x.y.z>` (clean `main` only) bumps `Resources/Info.plist`, commits, tags `v<x.y.z>` and pushes; `.github/workflows/release.yml` builds the tag, checks it matches `Info.plist` and publishes the `.dmg`, `.zip` and `checksums.txt` to GitHub Releases. `UpdateChecker` polls `releases/latest` daily (and on "检查更新…") and marks a newer release with an amber dot on the menu bar icon; it stays silent while the repository is private (the API returns 404). Clicking the update row runs `Updater`: download the release zip, verify it against `checksums.txt`, swap the bundle after quitting and relaunch; it falls back to the release page when the app can't be replaced. `CAMEO_UPDATE_FEED=file:///…/release.json` points both at a local fake release for testing.

Only Command Line Tools are required (no Xcode project). Do not add an `.xcodeproj`.

## Conventions

- Keep files small and single-purpose; match existing naming and comment density.
- Main-thread UI code is `@MainActor`; no third-party dependencies.
- User-facing text goes through `L("English text")` / `L("Format %@", arg)` (`Language.swift`); the English text is the key. Translations live in `Resources/Localizations/<code>.lproj/Localizable.strings` (zh-Hans, zh-Hant, ja, ko, es, fr, de, pt-BR, ru, it; `en.lproj` stays empty) and must gain every new key. The language follows macOS unless chosen in the popover, which writes the standard `AppleLanguages` default in Cameo's domain (the key System Settings' per-app language uses). `swift run` has no tables, so it shows English. READMEs exist in en, zh-CN, zh-TW, ja, ko, es, fr, de: keep them in step.
- User data lives in `~/Library/Application Support/Cameo/Characters` (imported videos are copied there) and `UserDefaults` (`selectedID`, `scale`, `visible`, `anchor`, `launched`, `lastUsed`, `AppleLanguages`).
- Commit in coherent batches with a short imperative subject.
