<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cameo 图标">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  一个轻量的 macOS 菜单栏应用，把带透明通道的角色视频放到你的桌面上。
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo 把一段循环播放的透明视频变成一个悬浮在桌面上的角色，始终置顶，在所有桌面空间（Space）都可见。角色可以随意拖动；点击透明区域时，点击会直接穿透到下面的窗口。

## 特性

- **内置一只猫**：银色虎斑英短 Chaofei（照着作者家的猫画的）由代码绘制，会沿着屏幕底部自己溜达：行走、蹲下、趴下（还会打瞌睡）、站立、打滚。点它会打滚，拖动时会被拎起来，也可以在菜单栏弹窗里指定动作。
- **真正透明**：只有角色的可见像素响应鼠标，其余区域全部点击穿透。
- **始终置顶**：悬浮在所有窗口之上，跨所有桌面空间。
- **原生格式**：支持 HEVC with Alpha 与 ProRes 4444（`.mov`），由 AVFoundation 解码，无需 FFmpeg，不内置编解码器。
- **省资源**：被全屏应用遮挡或屏幕休眠时暂停播放，使用电池时帧率限制为 30 fps。
- **极简**：只有一个菜单栏弹窗，包含显示/隐藏、角色、大小、开机启动。没有设置窗口，没有第三方依赖。

## 系统要求

- macOS 14 Sonoma 或更高版本（Apple 芯片或 Intel）
- 从源码构建：Xcode 命令行工具（`xcode-select --install`）

## 安装

### 下载

从 [Releases](https://github.com/wquguru/cameo/releases) 下载 **`Cameo-<version>-macOS-Universal.dmg`**：一个安装包同时支持 Apple 芯片和 Intel 芯片的 Mac（macOS 14 及以上）。打开后把 **Cameo** 拖进**应用程序**即可。旁边还有只含应用本身的 `.zip` 和 `checksums.txt`（SHA-256 校验值）。

应用使用 ad-hoc 签名（未经公证）。首次启动会被 macOS 拦截：打开**系统设置 › 隐私与安全性**，点击**仍要打开**；或者运行 `xattr -dr com.apple.quarantine /Applications/Cameo.app`。

### 更新

Cameo 每天检查一次 GitHub Releases，也可以在弹窗中点击“**检查更新…**”手动检查。有新版本时，菜单栏图标会出现一个琥珀色小圆点，这一行会变成**更新到 x.y.z**：点击后 Cameo 会下载新版本、校验其校验值、替换自身并重新打开。如果无法替换自身（例如不在“应用程序”文件夹中），则会改为打开发布页。**关于 Cameo** 会显示版本号以及项目链接。

### 语言

Cameo 支持 English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Português (Brasil), Русский 和 Italiano。默认跟随 Mac 的语言；如需切换，可在弹窗中使用**语言**，或前往“系统设置 › 通用 › 语言与地区 › 应用程序”。

### 从源码构建

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

## 使用

1. 点击菜单栏中的 Cameo 图标（一个从屏幕里探出头的小人）。
2. 点击 **+** 添加视频，或把视频拖到弹窗上，或在访达中选择**打开方式 → Cameo**。
3. 选择角色，把它拖到你喜欢的位置。

右键点击角色卡片可删除。导入的视频会被复制到 `~/Library/Application Support/Cameo/Characters`。

## 角色

### 角色库

在 **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** 浏览免费角色，点击**添加到 Cameo**，应用会自动下载并切换到该角色（通过 `cameo://add?url=…` 链接）。

### 制作角色

一个角色就是一段带透明通道、可循环的 `.mov`（HEVC with Alpha 或 ProRes 4444）。最简单的方式是让你的编码 agent 用仓库自带的 [`cameo-character`](skills/cameo-character/SKILL.md) skill 来做：

```bash
npx skills add wquguru/cameo --skill cameo-character
```

或者直接对 agent 说：*"安装这个 skill：https://github.com/wquguru/cameo/tree/main/skills/cameo-character"*。然后让它把一段绿幕视频做成角色，或者帮你写用 AI 视频工具生成角色的提示词。它会抠掉背景、校验结果并添加到 Cameo。

手动转换已带透明通道的视频：

```bash
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov
# 或使用 macOS 自带工具
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

做出了满意的角色？[投稿到角色库](https://github.com/wquguru/cameo/issues/new?template=character.yml)。

## 开发

```bash
swift build               # 调试构建
scripts/build.sh          # 发布版应用，输出到 build/Cameo.app
scripts/package.sh        # 通用架构的 .dmg、.zip 和 checksums.txt，输出到 build/
swift run CameoSample sample.mov                       # 生成一段带透明通道的测试视频
scripts/gallery-add.sh in.mov <id> "<name>" "@author" animal  # 发布一个角色到角色库
```

| 路径 | 用途 |
| --- | --- |
| `Sources/Cameo` | 应用本体（AppKit、SwiftUI 弹窗、AVFoundation 播放） |
| `Sources/CameoSample` | 生成 HEVC 透明示例视频的命令行工具 |
| `Sources/CameoIcon` | 渲染应用图标的命令行工具 |
| `design/` | 设计参考文件（用浏览器打开） |
| `gallery/` | 角色库网站，部署到 GitHub Pages |
| `skills/cameo-character` | 制作角色的 agent skill |

### 发布

```bash
scripts/release.sh 0.3.0   # 修改 Info.plist 版本号、提交、打 v0.3.0 标签并推送
```

`release` 工作流会构建该标签对应的提交，校验标签与 `Info.plist` 一致，然后把 `.dmg`、`.zip` 和 `checksums.txt` 发布到 GitHub Releases。

## 参与贡献

欢迎提交 Issue 和 Pull Request。Cameo 有意保持精简，新增功能前请先开 Issue 讨论。项目范围与约定见 [AGENTS.md](AGENTS.md)。

## 许可证

[Apache License 2.0](LICENSE)
