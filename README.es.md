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
- **Minimalista** — un popover en la barra de menús y una biblioteca de personajes sencilla. Sin ajustes ni dependencias.

## Requisitos

- macOS 14 Sonoma o posterior (Apple silicon o Intel)
- Para compilar desde el código fuente: Command Line Tools de Xcode (`xcode-select --install`)

## Instalación

### Descarga

Descarga **`Cameo-<version>-macOS-Universal.dmg`** desde [Releases](https://github.com/wquguru/cameo/releases): un único instalador para Mac con Apple silicon e Intel con macOS 14 o posterior. Ábrelo y arrastra **Cameo** a **Aplicaciones**. Junto a él encontrarás un `.zip` con la app sola y `checksums.txt` (SHA-256).

La app tiene una firma ad hoc (no está notarizada). La primera vez que la abras, macOS la bloqueará: ve a **Ajustes del Sistema › Privacidad y seguridad** y haz clic en **Abrir igualmente**, o ejecuta `xattr -dr com.apple.quarantine /Applications/Cameo.app`.

### Actualizaciones e idiomas

Cameo busca actualizaciones a diario y se actualiza solo desde el popover. Habla 11 idiomas y sigue el de tu Mac; elige otro en **Idioma** en el popover.

### Compilar desde el código fuente

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

### Desinstalar

Desactiva **Abrir al iniciar sesión** en el panel, cierra Cameo y muévelo a la Papelera. Los personajes importados y los ajustes se quedan hasta que borres `~/Library/Application Support/Cameo` y ejecutes `defaults delete io.github.wquguru.cameo`.

## Uso

1. Haz clic en el icono de Cameo (una figura asomándose por encima de una pantalla) en la barra de menús.
2. Añade un vídeo con **+**, soltándolo sobre el popover o mediante **Abrir con → Cameo** en el Finder.
3. Elige un personaje y arrastra la figura a donde quieras.

¿La barra de menús está llena y el icono queda oculto tras la muesca? Vuelve a abrir Cameo (Spotlight o Launchpad) o haz clic derecho en la figura para ver el mismo panel.

Mientras la figura está oculta, Cameo también aparece en el Dock: haz clic para abrir el panel o suelta un vídeo encima para añadirlo.

Cuando tengas más de unos pocos personajes, abre la biblioteca para buscarlos, renombrarlos o eliminarlos. Los vídeos importados se copian en `~/Library/Application Support/Cameo/Characters`.

## Personajes

### Galería

Explora personajes gratuitos en **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** y haz clic en **Add to Cameo**: la app descarga el personaje y cambia a él (mediante un enlace `cameo://add?url=…`).

### Crear un personaje

Un personaje es un único `.mov` en bucle con canal alfa (HEVC with Alpha o ProRes 4444). La forma más fácil es pedírselo a tu agente de programación con una de las skills incluidas:

| Tienes | Skill |
| --- | --- |
| Un clip con croma verde o un vídeo con alfa | [`cameo-from-video`](skills/cameo-from-video/SKILL.md) |
| Solo una descripción (requiere una clave de API de OpenRouter) | [`cameo-image-loop`](skills/cameo-image-loop/SKILL.md) |

Pega una de estas frases en tu agente de programación (Claude Code, Codex, Cursor…):

```text
Instala la skill de Cameo de https://github.com/wquguru/cameo/tree/main/skills/cameo-from-video y convierte ~/Downloads/dance.mp4 en un personaje de Cameo.
```

```text
Instala la skill de Cameo de https://github.com/wquguru/cameo/tree/main/skills/cameo-image-loop y crea un personaje de Cameo: una mujer con vestido amarillo, sentada, saludando.
```

Instala la skill, comprueba el resultado y añade el personaje a Cameo. Para instalarla en todos tus agentes a la vez, usa `npx skills add wquguru/cameo --skill <nombre>`.

¿Has hecho uno que te gusta? [Súbelo a la galería](https://wquguru.github.io/cameo/#submit) para que lo revisemos.

## Desarrollo

```bash
swift build                        # debug build
scripts/build.sh                   # release app bundle in build/Cameo.app
swift run CameoSample sample.mov   # a test clip with alpha
```

Consulta [AGENTS.md](AGENTS.md) para la estructura del proyecto, el empaquetado y las versiones.

## Contribuir

Los issues y pull requests son bienvenidos. Cameo es pequeño a propósito, así que abre un issue para hablar de nuevas funciones antes de añadir interfaz.

## Licencia

[Apache License 2.0](LICENSE)
