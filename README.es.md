<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Icono de Cameo">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  Una pequeña app para la barra de menús de macOS que pone un vídeo de un personaje con fondo transparente en tu escritorio.
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="Compilación"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Licencia: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo reproduce en bucle un vídeo con canal alfa como una figura flotante que permanece por encima de todas las ventanas y en todos los espacios. Arrastra la figura a donde quieras; los clics sobre sus píxeles transparentes pasan directamente a lo que haya debajo.

## Funciones

- **Incluye un gato** — Chaofei, un británico de pelo corto atigrado plateado dibujado en código a partir del gato del autor, deambula por la parte inferior de la pantalla: camina, se sienta, se tumba y se queda dormido, se pone de pie y rueda. Haz clic en él para que ruede, arrástralo para cogerlo en brazos o fija una acción desde el popover.
- **Transparencia real** — solo los píxeles visibles de la figura reciben el ratón; el resto deja pasar los clics.
- **Siempre visible** — flota por encima de todas las ventanas en todos los espacios.
- **Formatos nativos** — HEVC with Alpha y ProRes 4444 (`.mov`), decodificados por AVFoundation. Sin FFmpeg ni códecs incluidos.
- **Ligero** — se pausa cuando una app a pantalla completa lo oculta o mientras la pantalla está en reposo, y se limita a 30 fps con batería.
- **Minimalista** — un único popover en la barra de menús: mostrar/ocultar, personajes, tamaño y abrir al iniciar sesión. Sin ventanas de ajustes ni dependencias.

## Requisitos

- macOS 14 Sonoma o posterior (Apple silicon o Intel)
- Para compilar desde el código fuente: Command Line Tools de Xcode (`xcode-select --install`)

## Instalación

### Descarga

Descarga **`Cameo-<version>-macOS-Universal.dmg`** desde [Releases](https://github.com/wquguru/cameo/releases): un único instalador para Mac con Apple silicon e Intel con macOS 14 o posterior. Ábrelo y arrastra **Cameo** a **Aplicaciones**. Junto a él encontrarás un `.zip` con la app sola y `checksums.txt` (SHA-256).

La app tiene una firma ad hoc (no está notarizada). La primera vez que la abras, macOS la bloqueará: ve a **Ajustes del Sistema › Privacidad y seguridad** y haz clic en **Abrir igualmente**, o ejecuta `xattr -dr com.apple.quarantine /Applications/Cameo.app`.

### Actualizaciones

Cameo consulta GitHub Releases una vez al día, o cuando haces clic en **Buscar actualizaciones…** en el popover. Cuando hay una versión más reciente, el icono de la barra de menús muestra un punto ámbar y esa fila pasa a ser **Actualizar a x.y.z**: haz clic y Cameo descarga la versión, verifica su suma de comprobación, se reemplaza a sí mismo y se vuelve a abrir. Si no puede reemplazarse (por ejemplo, cuando no está en Aplicaciones), abre la página de la versión. **Acerca de Cameo** muestra la versión y enlaza al proyecto.

### Idiomas

Cameo está disponible en English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Português (Brasil), Русский e Italiano. Sigue el idioma de tu Mac; para elegir otro, usa **Idioma** en el popover o ve a Ajustes del Sistema › General › Idioma y región › Aplicaciones.

### Compilar desde el código fuente

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## Uso

1. Haz clic en el icono de Cameo (una figura asomándose por encima de una pantalla) en la barra de menús.
2. Añade un vídeo con **+**, soltándolo sobre el popover o mediante **Abrir con → Cameo** en el Finder.
3. Elige un personaje y arrastra la figura a donde quieras.

Haz clic con el botón derecho en la tarjeta de un personaje para eliminarlo. Los vídeos importados se copian en `~/Library/Application Support/Cameo/Characters`.

## Personajes

### Galería

Explora personajes gratuitos en **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** y haz clic en **Add to Cameo**: la app descarga el personaje y cambia a él (mediante un enlace `cameo://add?url=…`).

### Crear un personaje

Un personaje es un único `.mov` en bucle con canal alfa (HEVC with Alpha o ProRes 4444). La forma más fácil es pedírselo a tu agente de programación con la skill incluida [`cameo-character`](skills/cameo-character/SKILL.md):

```bash
npx skills add wquguru/cameo --skill cameo-character
```

O simplemente dile a tu agente: *"Instala la skill de https://github.com/wquguru/cameo/tree/main/skills/cameo-character"*. Después pídele que cree un personaje a partir de un clip con croma verde, o que escriba el prompt para generar uno con una herramienta de vídeo con IA. Elimina el fondo, comprueba el resultado y lo añade a Cameo.

A mano, para un clip que ya tiene canal alfa:

```bash
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or Apple's built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

¿Has hecho uno que te gusta? [Envíalo a la galería](https://github.com/wquguru/cameo/issues/new?template=character.yml).

## Desarrollo

```bash
swift build               # debug build
scripts/build.sh          # release app bundle in build/Cameo.app
scripts/package.sh        # universal .dmg, .zip and checksums.txt in build/
swift run CameoSample sample.mov                       # a test clip with alpha
scripts/gallery-add.sh in.mov <id> "<name>" "@author" animal  # publish a gallery character
```

| Ruta | Función |
| --- | --- |
| `Sources/Cameo` | La app (AppKit, popover en SwiftUI, reproducción con AVFoundation) |
| `Sources/CameoSample` | CLI que genera un clip de ejemplo HEVC con alfa |
| `Sources/CameoIcon` | CLI que renderiza el icono de la app |
| `design/` | Archivos de referencia de diseño (se abren en un navegador) |
| `gallery/` | Web de la galería de personajes, desplegada en GitHub Pages |
| `skills/cameo-character` | Skill de agente para crear personajes |

### Publicar una versión

```bash
scripts/release.sh 0.3.0   # bumps Info.plist, commits, tags v0.3.0 and pushes
```

El workflow `release` compila el commit etiquetado, comprueba que la etiqueta coincide con `Info.plist` y publica el `.dmg`, el `.zip` y `checksums.txt` en GitHub Releases.

## Contribuir

Los issues y pull requests son bienvenidos. Cameo es pequeño a propósito, así que abre un issue para hablar de nuevas funciones antes de añadir interfaz. Consulta [AGENTS.md](AGENTS.md) para conocer el alcance y las convenciones.

## Licencia

[Apache License 2.0](LICENSE)
