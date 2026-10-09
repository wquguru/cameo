<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cameo 아이콘">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  투명한 캐릭터 동영상을 데스크탑에 띄워 주는 작은 macOS 메뉴 막대 앱입니다.
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="빌드"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="라이선스: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo는 알파 채널이 있는 반복 재생 동영상을 모든 윈도우와 모든 스페이스 위에 떠 있는 캐릭터로 재생합니다. 캐릭터는 어디로든 드래그할 수 있으며, 투명한 픽셀을 클릭하면 클릭이 그대로 아래에 있는 항목으로 전달됩니다.

## 기능

- **고양이 기본 내장** — Chaofei는 제작자가 키우는 고양이를 본떠 코드로 그린 실버 태비 브리티시 쇼트헤어로, 화면 아래쪽을 따라 돌아다닙니다. 걷고, 앉고, 엎드려 졸고, 일어서고, 구릅니다. 클릭하면 구르고, 드래그하면 들어 올려지며, 팝오버에서 동작을 고정할 수도 있습니다.
- **진짜 투명** — 캐릭터의 보이는 픽셀만 마우스에 반응하고, 나머지는 모두 클릭이 통과합니다.
- **항상 위에** — 모든 스페이스에서 모든 윈도우 위에 떠 있습니다.
- **네이티브 포맷** — HEVC with Alpha와 ProRes 4444(`.mov`)를 AVFoundation으로 디코딩합니다. FFmpeg도, 번들 코덱도 필요 없습니다.
- **가벼운 리소스 사용** — 전체 화면 앱에 가려지거나 화면이 잠자기 상태일 때 일시 정지하며, 배터리 사용 시 30fps로 제한합니다.
- **미니멀** — 메뉴 막대 팝오버 하나뿐입니다. 보기/가리기, 캐릭터, 크기, 로그인 시 실행. 설정 윈도우도, 의존성도 없습니다.

## 요구 사항

- macOS 14 Sonoma 이상(Apple 실리콘 또는 Intel)
- 소스에서 빌드하는 경우: Xcode 명령어 라인 도구(`xcode-select --install`)

## 설치

### 다운로드

[Releases](https://github.com/wquguru/cameo/releases)에서 **`Cameo-<version>-macOS-Universal.dmg`** 파일을 다운로드하십시오. macOS 14 이상을 실행하는 Apple 실리콘 Mac과 Intel Mac 모두에서 쓸 수 있는 설치 파일 하나입니다. 파일을 열고 **Cameo**를 **응용 프로그램**으로 드래그하면 됩니다. 앱만 담긴 `.zip`과 `checksums.txt`(SHA-256)도 함께 제공됩니다.

이 앱은 ad-hoc 서명되어 있습니다(공증되지 않음). 처음 실행할 때 macOS가 차단하므로 **시스템 설정 › 개인정보 보호 및 보안**을 열고 **그래도 열기**를 클릭하거나, `xattr -dr com.apple.quarantine /Applications/Cameo.app`을 실행하십시오.

### 업데이트

Cameo는 하루에 한 번, 또는 팝오버에서 **업데이트 확인…** 항목을 클릭할 때 GitHub Releases를 확인합니다. 새 버전이 나오면 메뉴 막대 아이콘에 호박색 점이 표시되고 해당 행이 **x.y.z(으)로 업데이트**로 바뀝니다. 클릭하면 Cameo가 릴리스를 다운로드하고, 체크섬을 확인한 뒤, 자신을 교체하고 다시 엽니다. 자신을 교체할 수 없는 경우(예: 응용 프로그램 폴더에 있지 않을 때)에는 대신 릴리스 페이지를 엽니다. **Cameo에 관하여**에서는 버전을 확인하고 프로젝트 링크로 이동할 수 있습니다.

### 언어

Cameo는 English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Português (Brasil), Русский, Italiano를 지원합니다. Mac의 언어를 따르며, 다른 언어를 고르려면 팝오버의 **언어**를 사용하거나 시스템 설정 › 일반 › 언어 및 지역 › 응용 프로그램에서 설정하십시오.

### 소스에서 빌드

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## 사용법

1. 메뉴 막대에서 Cameo 아이콘(화면 밖으로 고개를 내민 사람 모양)을 클릭합니다.
2. **+** 버튼으로 동영상을 추가하거나, 팝오버에 동영상을 드롭하거나, Finder에서 **다음으로 열기 → Cameo**를 선택합니다.
3. 캐릭터를 고르고 원하는 곳으로 드래그합니다.

캐릭터 카드를 오른쪽 클릭하면 삭제할 수 있습니다. 가져온 동영상은 `~/Library/Application Support/Cameo/Characters`에 복사됩니다.

## 캐릭터

### 갤러리

**[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** 사이트에서 무료 캐릭터를 둘러보고 **Add to Cameo**를 클릭하면, 앱이 캐릭터를 다운로드하고 해당 캐릭터로 전환합니다(`cameo://add?url=…` 링크 사용).

### 캐릭터 만들기

캐릭터는 알파가 있는 반복 재생 `.mov`(HEVC with Alpha 또는 ProRes 4444) 하나입니다. 가장 쉬운 방법은 함께 제공되는 [`cameo-character`](skills/cameo-character/SKILL.md) 스킬로 코딩 에이전트에게 맡기는 것입니다.

```bash
npx skills add wquguru/cameo --skill cameo-character
```

또는 에이전트에게 *"https://github.com/wquguru/cameo/tree/main/skills/cameo-character 에 있는 스킬을 설치해 줘"*라고 말하기만 하면 됩니다. 그런 다음 그린 스크린 영상으로 캐릭터를 만들어 달라고 하거나, AI 동영상 도구로 캐릭터를 생성할 프롬프트를 써 달라고 요청하십시오. 에이전트가 배경을 제거하고 결과를 확인한 뒤 Cameo에 추가합니다.

이미 알파가 있는 영상을 직접 변환하려면:

```bash
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# or Apple's built-in tool
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

마음에 드는 캐릭터를 만들었다면 [갤러리에 제출](https://github.com/wquguru/cameo/issues/new?template=character.yml)해 주세요.

## 개발

```bash
swift build               # debug build
scripts/build.sh          # release app bundle in build/Cameo.app
scripts/package.sh        # universal .dmg, .zip and checksums.txt in build/
swift run CameoSample sample.mov                       # a test clip with alpha
scripts/gallery-add.sh in.mov <id> "<name>" "@author"  # publish a gallery character
```

| 경로 | 용도 |
| --- | --- |
| `Sources/Cameo` | 앱 본체(AppKit, SwiftUI 팝오버, AVFoundation 재생) |
| `Sources/CameoSample` | HEVC 알파 샘플 영상을 만드는 CLI |
| `Sources/CameoIcon` | 앱 아이콘을 렌더링하는 CLI |
| `design/` | 디자인 참고 파일(브라우저에서 열기) |
| `gallery/` | 캐릭터 갤러리 사이트, GitHub Pages에 배포 |
| `skills/cameo-character` | 캐릭터 제작용 에이전트 스킬 |

### 릴리스

```bash
scripts/release.sh 0.3.0   # bumps Info.plist, commits, tags v0.3.0 and pushes
```

`release` 워크플로는 태그가 붙은 커밋을 빌드하고, 태그가 `Info.plist`와 일치하는지 확인한 뒤, `.dmg`, `.zip`, `checksums.txt`를 GitHub Releases에 게시합니다.

## 기여하기

이슈와 풀 리퀘스트를 환영합니다. Cameo는 의도적으로 작게 유지하고 있으므로, UI를 추가하기 전에 먼저 이슈를 열어 새 기능을 논의해 주세요. 범위와 규칙은 [AGENTS.md](AGENTS.md)를 참고하십시오.

## 라이선스

[Apache License 2.0](LICENSE)
