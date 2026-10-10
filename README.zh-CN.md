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
- **极简**：一个菜单栏弹窗，加一个简洁的角色资料库。没有设置项，没有第三方依赖。

## 系统要求

- macOS 14 Sonoma 或更高版本（Apple 芯片或 Intel）
- 从源码构建：Xcode 命令行工具（`xcode-select --install`）

## 安装

### 下载

从 [Releases](https://github.com/wquguru/cameo/releases) 下载 **`Cameo-<version>-macOS-Universal.dmg`**：一个安装包同时支持 Apple 芯片和 Intel 芯片的 Mac（macOS 14 及以上）。打开后把 **Cameo** 拖进**应用程序**即可。旁边还有只含应用本身的 `.zip` 和 `checksums.txt`（SHA-256 校验值）。

应用使用 ad-hoc 签名（未经公证）。首次启动会被 macOS 拦截：打开**系统设置 › 隐私与安全性**，点击**仍要打开**；或者运行 `xattr -dr com.apple.quarantine /Applications/Cameo.app`。

### 更新与语言

Cameo 每天检查更新，并可在弹窗中一键更新自身。它支持 11 种语言，默认跟随 Mac 的语言；如需切换，可在弹窗中使用**语言**。

### 从源码构建

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

### 卸载

先在弹窗里关掉「登录时启动」，退出 Cameo，再把它移到废纸篓。导入的角色和设置会留在原处，删除 `~/Library/Application Support/Cameo` 并运行 `defaults delete io.github.wquguru.cameo` 即可清除。

## 使用

1. 点击菜单栏中的 Cameo 图标（一个从屏幕里探出头的小人）。
2. 点击 **+** 添加视频，或把视频拖到弹窗上，或在访达中选择**打开方式 → Cameo**。
3. 选择角色，把它拖到你喜欢的位置。

菜单栏太满，图标被刘海挡住了？再次打开 Cameo（聚焦搜索或启动台），或右键点角色，就能打开同一个弹窗。

角色隐藏期间，Cameo 也会留在 Dock 里：点它打开弹窗，把视频拖到它上面就能添加。

角色较多时，可打开资料库来搜索、重命名或移除角色。导入的视频会被复制到 `~/Library/Application Support/Cameo/Characters`。

## 角色

### 角色库

在 **[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** 浏览免费角色，点击**添加到 Cameo**，应用会自动下载并切换到该角色（通过 `cameo://add?url=…` 链接）。

### 制作角色

一个角色就是一段带透明通道、可循环的 `.mov`（HEVC with Alpha 或 ProRes 4444）。最简单的方式是让你的编码 agent 用仓库自带的 skill 来做：

| 你手上有 | Skill |
| --- | --- |
| 一段绿幕视频，或带透明通道的视频 | [`cameo-from-video`](skills/cameo-from-video/SKILL.md) |
| 只有一句描述（需要 OpenRouter API key） | [`cameo-image-loop`](skills/cameo-image-loop/SKILL.md) |

把下面一句话发给你的编程 Agent（Claude Code、Codex、Cursor 等）：

```text
安装 https://github.com/wquguru/cameo/tree/main/skills/cameo-from-video 这个 Cameo skill，然后把 ~/Downloads/dance.mp4 做成 Cameo 角色。
```

```text
安装 https://github.com/wquguru/cameo/tree/main/skills/cameo-image-loop 这个 Cameo skill，然后做一个 Cameo 角色：穿黄色连衣裙的女生，坐着挥手。
```

它会装好 skill、校验结果并把角色添加到 Cameo。想一次装给所有 Agent，可以改用 `npx skills add wquguru/cameo --skill <名称>`。

做出了满意的角色？[上传到角色库](https://wquguru.github.io/cameo/#submit)等待审核。

## 开发

```bash
swift build                        # 调试构建
scripts/build.sh                   # 发布版应用，输出到 build/Cameo.app
swift run CameoSample sample.mov   # 生成一段带透明通道的测试视频
```

项目结构、打包与发布见 [AGENTS.md](AGENTS.md)。

## 参与贡献

欢迎提交 Issue 和 Pull Request。Cameo 有意保持精简，新增功能前请先开 Issue 讨论。

## 许可证

[Apache License 2.0](LICENSE)
