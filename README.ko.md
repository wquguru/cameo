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
- **미니멀** — 메뉴 막대 팝오버와 단순한 캐릭터 라이브러리뿐입니다. 설정도, 의존성도 없습니다.

## 요구 사항

- macOS 14 Sonoma 이상(Apple 실리콘 또는 Intel)
- 소스에서 빌드하는 경우: Xcode 명령어 라인 도구(`xcode-select --install`)

## 설치

### 다운로드

[Releases](https://github.com/wquguru/cameo/releases)에서 **`Cameo-<version>-macOS-Universal.dmg`** 파일을 다운로드하십시오. macOS 14 이상을 실행하는 Apple 실리콘 Mac과 Intel Mac 모두에서 쓸 수 있는 설치 파일 하나입니다. 파일을 열고 **Cameo**를 **응용 프로그램**으로 드래그하면 됩니다. 앱만 담긴 `.zip`과 `checksums.txt`(SHA-256)도 함께 제공됩니다.

이 앱은 ad-hoc 서명되어 있습니다(공증되지 않음). 처음 실행할 때 macOS가 차단하므로 **시스템 설정 › 개인정보 보호 및 보안**을 열고 **그래도 열기**를 클릭하거나, `xattr -dr com.apple.quarantine /Applications/Cameo.app`을 실행하십시오.

### 업데이트와 언어

Cameo는 매일 업데이트를 확인하고 팝오버에서 스스로 업데이트합니다. 11개 언어를 지원하며 Mac의 언어를 따릅니다. 다른 언어를 고르려면 팝오버의 **언어**를 사용하십시오.

### 소스에서 빌드

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

### 제거

팝오버에서 '로그인 시 열기'를 끄고 Cameo를 종료한 뒤 휴지통으로 옮깁니다. 가져온 캐릭터와 설정은 남아 있으므로 `~/Library/Application Support/Cameo`를 삭제하고 `defaults delete io.github.wquguru.cameo`를 실행하면 지워집니다.

## 사용법

1. 메뉴 막대에서 Cameo 아이콘(화면 밖으로 고개를 내민 사람 모양)을 클릭합니다.
2. **+** 버튼으로 동영상을 추가하거나, 팝오버에 동영상을 드롭하거나, Finder에서 **다음으로 열기 → Cameo**를 선택합니다.
3. 캐릭터를 고르고 원하는 곳으로 드래그합니다.

메뉴 막대가 꽉 차서 아이콘이 노치에 가려졌다면 Cameo를 다시 열거나(Spotlight 또는 Launchpad) 캐릭터를 오른쪽 클릭하면 같은 팝오버가 열립니다.

캐릭터를 숨긴 동안에는 Cameo가 Dock에도 나타납니다. 클릭하면 팝오버가 열리고, 비디오를 끌어다 놓으면 추가됩니다.

캐릭터가 많아지면 라이브러리를 열어 검색하거나, 이름을 변경하거나, 제거할 수 있습니다. 가져온 동영상은 `~/Library/Application Support/Cameo/Characters`에 복사됩니다.

## 캐릭터

### 갤러리

**[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** 사이트에서 무료 캐릭터를 둘러보고 **Add to Cameo**를 클릭하면, 앱이 캐릭터를 다운로드하고 해당 캐릭터로 전환합니다(`cameo://add?url=…` 링크 사용).

### 캐릭터 만들기

캐릭터는 알파가 있는 반복 재생 `.mov`(HEVC with Alpha 또는 ProRes 4444) 하나입니다. 가장 쉬운 방법은 함께 제공되는 스킬로 코딩 에이전트에게 맡기는 것입니다.

| 가지고 있는 것 | 스킬 |
| --- | --- |
| 그린 스크린 영상 또는 알파가 있는 영상 | [`cameo-from-video`](skills/cameo-from-video/SKILL.md) |
| 설명뿐 (OpenRouter API 키 필요) | [`cameo-image-loop`](skills/cameo-image-loop/SKILL.md) |

```bash
npx skills add wquguru/cameo --skill cameo-from-video  # 영상에서
npx skills add wquguru/cameo --skill cameo-image-loop  # 설명에서
```

그런 다음 *"~/Downloads/dance.mp4를 Cameo 캐릭터로 만들어 줘"* 또는 *"Cameo 캐릭터를 만들어 줘: 노란 원피스를 입은 여성, 앉아서 손 흔들기"*처럼 요청하면 됩니다. 결과를 확인한 뒤 Cameo에 추가합니다.

마음에 드는 캐릭터를 만들었다면 [갤러리에 업로드](https://wquguru.github.io/cameo/#submit)해 검토를 받아 보세요.

## 개발

```bash
swift build                        # debug build
scripts/build.sh                   # release app bundle in build/Cameo.app
swift run CameoSample sample.mov   # a test clip with alpha
```

프로젝트 구조, 패키징, 릴리스는 [AGENTS.md](AGENTS.md)를 참고하십시오.

## 기여하기

이슈와 풀 리퀘스트를 환영합니다. Cameo는 의도적으로 작게 유지하고 있으므로, UI를 추가하기 전에 먼저 이슈를 열어 새 기능을 논의해 주세요.

## 라이선스

[Apache License 2.0](LICENSE)
