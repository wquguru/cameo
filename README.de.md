<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cameo-Symbol">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  Eine winzige macOS-Menüleisten-App, die ein transparentes Figurenvideo auf deinen Schreibtisch setzt.
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Lizenz: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo spielt ein Video mit Alphakanal in Endlosschleife als frei schwebende Figur ab, die über allen Fenstern und in jedem Space bleibt. Zieh die Figur an eine beliebige Stelle; Klicks auf ihre transparenten Pixel gehen direkt an das, was darunter liegt.

## Funktionen

- **Eine Katze ist schon dabei** — Chaofei, eine silber getigerte Britisch Kurzhaar, in Code gezeichnet nach dem Vorbild der Katze des Autors, streift am unteren Bildschirmrand umher: Sie läuft, sitzt, legt sich hin und döst ein, steht auf und rollt sich. Klick sie an, damit sie sich rollt, zieh sie, um sie hochzuheben, oder leg im Popover eine feste Aktion fest.
- **Wirklich transparent** — nur die sichtbaren Pixel der Figur reagieren auf die Maus; alles andere lässt Klicks durch.
- **Immer im Vordergrund** — schwebt in jedem Space über allen Fenstern.
- **Native Formate** — HEVC with Alpha und ProRes 4444 (`.mov`), dekodiert von AVFoundation. Kein FFmpeg, keine mitgelieferten Codecs.
- **Ressourcenschonend** — pausiert, wenn eine Vollbild-App sie verdeckt oder der Bildschirm im Ruhezustand ist, und begrenzt im Batteriebetrieb auf 30 fps.
- **Minimal** — ein einziges Menüleisten-Popover: Einblenden/Ausblenden, Figuren, Größe, Beim Anmelden öffnen. Keine Einstellungsfenster, keine Abhängigkeiten.

## Voraussetzungen

- macOS 14 Sonoma oder neuer (Apple Chip oder Intel)
- Zum Kompilieren aus dem Quellcode: Xcode Command Line Tools (`xcode-select --install`)

## Installation

### Download

Lade **`Cameo-<version>-macOS-Universal.dmg`** von [Releases](https://github.com/wquguru/cameo/releases) — ein Installationsprogramm für Macs mit Apple Chip und Intel ab macOS 14. Öffne es und zieh **Cameo** in den Ordner **Programme**. Daneben liegen ein `.zip` mit der reinen App und `checksums.txt` (SHA-256).

Die App ist ad-hoc signiert (nicht notarisiert). Beim ersten Start blockiert macOS sie: Öffne **Systemeinstellungen › Datenschutz & Sicherheit** und klicke auf **Dennoch öffnen**, oder führe `xattr -dr com.apple.quarantine /Applications/Cameo.app` aus.

### Updates

Cameo prüft einmal täglich GitHub Releases, oder wenn du im Popover auf **Nach Updates suchen …** klickst. Ist eine neuere Version verfügbar, bekommt das Menüleistensymbol einen bernsteinfarbenen Punkt, und diese Zeile wird zu **Auf x.y.z aktualisieren**: Klick darauf, und Cameo lädt das Release herunter, prüft seine Prüfsumme, ersetzt sich selbst und öffnet sich erneut. Kann es sich nicht selbst ersetzen (zum Beispiel, wenn es nicht im Ordner „Programme“ liegt), öffnet es stattdessen die Release-Seite. **Über Cameo** zeigt die Version und verlinkt auf das Projekt.

### Sprachen

Cameo spricht English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Português (Brasil), Русский und Italiano. Es folgt der Sprache deines Mac; um eine andere zu wählen, nutze **Sprache** im Popover oder Systemeinstellungen › Allgemein › Sprache & Region › Programme.

### Aus dem Quellcode kompilieren

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## Verwendung

1. Klicke in der Menüleiste auf das Cameo-Symbol (eine Figur, die aus einem Bildschirm hervorschaut).
2. Füge ein Video mit **+** hinzu, leg es auf dem Popover ab oder wähle im Finder **Öffnen mit → Cameo**.
3. Wähle eine Figur und zieh sie an die gewünschte Stelle.

Klicke mit der rechten Maustaste auf die Karte einer Figur, um sie zu löschen. Importierte Videos werden nach `~/Library/Application Support/Cameo/Characters` kopiert.

## Figuren

### Galerie

Stöbere auf **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** durch kostenlose Figuren und klicke auf **Add to Cameo**: Die App lädt die Figur herunter und wechselt zu ihr (über einen `cameo://add?url=…`-Link).

### Eine Figur erstellen

Eine Figur ist eine einzelne `.mov`-Endlosschleife mit Alphakanal (HEVC with Alpha oder ProRes 4444). Am einfachsten lässt du das deinen Coding-Agent mit dem mitgelieferten Skill [`cameo-character`](skills/cameo-character/SKILL.md) erledigen:

```bash
npx skills add wquguru/cameo --skill cameo-character
```

Oder sag deinem Agent einfach: *„Installiere den Skill unter https://github.com/wquguru/cameo/tree/main/skills/cameo-character“*. Bitte ihn dann, aus einem Greenscreen-Clip eine Figur zu machen oder den Prompt zu schreiben, um eine mit einem KI-Videotool zu generieren. Er stellt den Hintergrund frei, prüft das Ergebnis und fügt die Figur zu Cameo hinzu.

Von Hand, für einen Clip, der bereits einen Alphakanal hat:

```bash
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or Apple's built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

Eine gelungene Figur erstellt? [Reiche sie für die Galerie ein](https://github.com/wquguru/cameo/issues/new?template=character.yml).

## Entwicklung

```bash
swift build               # debug build
scripts/build.sh          # release app bundle in build/Cameo.app
scripts/package.sh        # universal .dmg, .zip and checksums.txt in build/
swift run CameoSample sample.mov                       # a test clip with alpha
scripts/gallery-add.sh in.mov <id> "<name>" "@author" animal  # publish a gallery character
```

| Pfad | Zweck |
| --- | --- |
| `Sources/Cameo` | Die App (AppKit, SwiftUI-Popover, Wiedergabe mit AVFoundation) |
| `Sources/CameoSample` | CLI, das einen HEVC-Alpha-Beispielclip schreibt |
| `Sources/CameoIcon` | CLI, das das App-Symbol rendert |
| `design/` | Design-Referenzdateien (im Browser öffnen) |
| `gallery/` | Website der Figurengalerie, auf GitHub Pages bereitgestellt |
| `skills/cameo-character` | Agent-Skill zum Erstellen von Figuren |

### Releases veröffentlichen

```bash
scripts/release.sh 0.3.0   # bumps Info.plist, commits, tags v0.3.0 and pushes
```

Der `release`-Workflow kompiliert den getaggten Commit, prüft, ob der Tag zu `Info.plist` passt, und veröffentlicht die `.dmg`, das `.zip` und `checksums.txt` auf GitHub Releases.

## Mitwirken

Issues und Pull Requests sind willkommen. Cameo ist bewusst klein gehalten, daher eröffne bitte zuerst ein Issue, um neue Funktionen zu besprechen, bevor du UI hinzufügst. Umfang und Konventionen findest du in [AGENTS.md](AGENTS.md).

## Lizenz

[Apache License 2.0](LICENSE)
