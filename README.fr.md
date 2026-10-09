<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Icône de Cameo">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  Une petite app pour la barre des menus de macOS qui pose une vidéo de personnage transparente sur votre bureau.
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="Compilation"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Licence : Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo lit en boucle une vidéo dotée d’une couche alpha sous la forme d’un personnage flottant qui reste au-dessus de toutes les fenêtres, dans chaque Space. Faites glisser le personnage où vous voulez ; les clics sur ses pixels transparents passent directement à ce qui se trouve en dessous.

## Fonctionnalités

- **Un chat intégré** — Chaofei, un British Shorthair tabby argenté dessiné en code d’après le chat de l’auteur, se promène en bas de l’écran : il marche, s’assoit, se couche et s’assoupit, se lève et se roule par terre. Cliquez dessus pour qu’il se roule, faites-le glisser pour le prendre, ou fixez une action depuis la fenêtre contextuelle.
- **Vraiment transparent** — seuls les pixels visibles du personnage captent la souris ; tout le reste laisse passer les clics.
- **Toujours au premier plan** — flotte au-dessus de toutes les fenêtres, dans chaque Space.
- **Formats natifs** — HEVC with Alpha et ProRes 4444 (`.mov`), décodés par AVFoundation. Pas de FFmpeg, aucun codec embarqué.
- **Économe en ressources** — se met en pause lorsqu’une app en plein écran le masque ou pendant la suspension de l’écran, et se limite à 30 ips sur batterie.
- **Minimaliste** — une seule fenêtre contextuelle dans la barre des menus : afficher/masquer, personnages, taille, ouverture à la connexion. Pas de fenêtre de réglages, aucune dépendance.

## Configuration requise

- macOS 14 Sonoma ou ultérieur (puce Apple ou Intel)
- Pour compiler depuis les sources : outils de ligne de commande Xcode (`xcode-select --install`)

## Installation

### Téléchargement

Téléchargez **`Cameo-<version>-macOS-Universal.dmg`** depuis [Releases](https://github.com/wquguru/cameo/releases) : un seul programme d’installation pour les Mac à puce Apple et Intel sous macOS 14 ou ultérieur. Ouvrez-le et faites glisser **Cameo** dans **Applications**. Un `.zip` contenant l’app seule et `checksums.txt` (SHA-256) sont fournis à côté.

L’app a une signature ad hoc (elle n’est pas notariée). Au premier lancement, macOS la bloque : ouvrez **Réglages Système › Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**, ou exécutez `xattr -dr com.apple.quarantine /Applications/Cameo.app`.

### Mises à jour

Cameo consulte GitHub Releases une fois par jour, ou lorsque vous cliquez sur **Rechercher les mises à jour…** dans la fenêtre contextuelle. Lorsqu’une version plus récente est disponible, l’icône de la barre des menus affiche un point ambre et cette ligne devient **Mettre à jour vers x.y.z** : cliquez dessus et Cameo télécharge la version, vérifie sa somme de contrôle, se remplace lui-même et se rouvre. S’il ne peut pas se remplacer (par exemple lorsqu’il ne se trouve pas dans Applications), il ouvre plutôt la page de la version. **À propos de Cameo** affiche la version et renvoie vers le projet.

### Langues

Cameo parle English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Português (Brasil), Русский et Italiano. Il suit la langue de votre Mac ; pour en choisir une autre, utilisez **Langue** dans la fenêtre contextuelle, ou Réglages Système › Général › Langue et région › Applications.

### Compiler depuis les sources

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## Utilisation

1. Cliquez sur l’icône de Cameo (un personnage qui dépasse d’un écran) dans la barre des menus.
2. Ajoutez une vidéo avec **+**, en la déposant sur la fenêtre contextuelle, ou via **Ouvrir avec → Cameo** dans le Finder.
3. Choisissez un personnage et faites-le glisser où vous le souhaitez.

Cliquez avec le bouton droit sur la carte d’un personnage pour le supprimer. Les vidéos importées sont copiées dans `~/Library/Application Support/Cameo/Characters`.

## Personnages

### Galerie

Parcourez des personnages gratuits sur **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** et cliquez sur **Add to Cameo** : l’app télécharge le personnage et passe à celui-ci (via un lien `cameo://add?url=…`).

### Créer un personnage

Un personnage est un seul `.mov` en boucle avec couche alpha (HEVC with Alpha ou ProRes 4444). Le plus simple est de confier la tâche à votre agent de code avec la skill fournie [`cameo-character`](skills/cameo-character/SKILL.md) :

```bash
npx skills add wquguru/cameo --skill cameo-character
```

Ou dites simplement à votre agent : *« Installe la skill qui se trouve à https://github.com/wquguru/cameo/tree/main/skills/cameo-character »*. Demandez-lui ensuite de créer un personnage à partir d’un clip sur fond vert, ou de rédiger le prompt pour en générer un avec un outil vidéo d’IA. Il détoure l’arrière-plan, vérifie le résultat et l’ajoute à Cameo.

À la main, pour un clip qui possède déjà une couche alpha :

```bash
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or Apple's built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

Vous en avez créé un qui vous plaît ? [Proposez-le pour la galerie](https://github.com/wquguru/cameo/issues/new?template=character.yml).

## Développement

```bash
swift build               # debug build
scripts/build.sh          # release app bundle in build/Cameo.app
scripts/package.sh        # universal .dmg, .zip and checksums.txt in build/
swift run CameoSample sample.mov                       # a test clip with alpha
scripts/gallery-add.sh in.mov <id> "<name>" "@author" animal  # publish a gallery character
```

| Chemin | Rôle |
| --- | --- |
| `Sources/Cameo` | L’app (AppKit, fenêtre contextuelle SwiftUI, lecture AVFoundation) |
| `Sources/CameoSample` | CLI qui génère un clip d’exemple HEVC avec alpha |
| `Sources/CameoIcon` | CLI qui produit l’icône de l’app |
| `design/` | Fichiers de référence de design (à ouvrir dans un navigateur) |
| `gallery/` | Site de la galerie de personnages, déployé sur GitHub Pages |
| `skills/cameo-character` | Skill d’agent pour créer des personnages |

### Publier une version

```bash
scripts/release.sh 0.3.0   # bumps Info.plist, commits, tags v0.3.0 and pushes
```

Le workflow `release` compile le commit tagué, vérifie que le tag correspond à `Info.plist`, puis publie le `.dmg`, le `.zip` et `checksums.txt` sur GitHub Releases.

## Contribuer

Les issues et pull requests sont les bienvenues. Cameo est volontairement réduit à l’essentiel : merci d’ouvrir une issue pour discuter de toute nouvelle fonctionnalité avant d’ajouter de l’interface. Consultez [AGENTS.md](AGENTS.md) pour le périmètre et les conventions.

## Licence

[Apache License 2.0](LICENSE)
