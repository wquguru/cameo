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
- **Minimal** — ein Menüleisten-Popover und eine schlichte Figurenbibliothek. Keine Einstellungen, keine Abhängigkeiten.

## Voraussetzungen

- macOS 14 Sonoma oder neuer (Apple Chip oder Intel)
- Zum Kompilieren aus dem Quellcode: Xcode Command Line Tools (`xcode-select --install`)

## Installation

### Download

Lade **`Cameo-<version>-macOS-Universal.dmg`** von [Releases](https://github.com/wquguru/cameo/releases) — ein Installationsprogramm für Macs mit Apple Chip und Intel ab macOS 14. Öffne es und zieh **Cameo** in den Ordner **Programme**. Daneben liegen ein `.zip` mit der reinen App und `checksums.txt` (SHA-256).

Die App ist ad-hoc signiert (nicht notarisiert). Beim ersten Start blockiert macOS sie: Öffne **Systemeinstellungen › Datenschutz & Sicherheit** und klicke auf **Dennoch öffnen**, oder führe `xattr -dr com.apple.quarantine /Applications/Cameo.app` aus.

### Updates und Sprachen

Cameo sucht täglich nach Updates und aktualisiert sich selbst über das Popover. Es spricht 11 Sprachen und folgt der Sprache deines Mac; eine andere wählst du unter **Sprache** im Popover.

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

Sobald du mehr als eine Handvoll Figuren hast, öffne die Bibliothek, um sie zu suchen, umzubenennen oder zu entfernen. Importierte Videos werden nach `~/Library/Application Support/Cameo/Characters` kopiert.

## Figuren

### Galerie

Stöbere auf **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** durch kostenlose Figuren und klicke auf **Add to Cameo**: Die App lädt die Figur herunter und wechselt zu ihr (über einen `cameo://add?url=…`-Link).

### Eine Figur erstellen

Eine Figur ist eine einzelne `.mov`-Endlosschleife mit Alphakanal (HEVC with Alpha oder ProRes 4444). Am einfachsten lässt du das deinen Coding-Agent mit dem mitgelieferten Skill [`cameo-character`](skills/cameo-character/SKILL.md) erledigen:

```bash
npx skills add wquguru/cameo --skill cameo-character
```

Oder sag deinem Agent einfach: *„Installiere den Skill unter https://github.com/wquguru/cameo/tree/main/skills/cameo-character“*. Bitte ihn dann, aus einem Greenscreen-Clip eine Figur zu machen oder den Prompt zu schreiben, um eine mit einem KI-Videotool zu generieren. Er stellt den Hintergrund frei, prüft das Ergebnis und fügt die Figur zu Cameo hinzu.

Eine gelungene Figur erstellt? [Lade sie in die Galerie hoch](https://wquguru.github.io/cameo/#submit), damit wir sie prüfen können.

## Entwicklung

```bash
swift build                        # debug build
scripts/build.sh                   # release app bundle in build/Cameo.app
swift run CameoSample sample.mov   # a test clip with alpha
```

Projektstruktur, Packaging und Releases findest du in [AGENTS.md](AGENTS.md).

## Mitwirken

Issues und Pull Requests sind willkommen. Cameo ist bewusst klein gehalten, daher eröffne bitte zuerst ein Issue, um neue Funktionen zu besprechen, bevor du UI hinzufügst.

## Lizenz

[Apache License 2.0](LICENSE)
