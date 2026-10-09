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

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

---

Cameo 把一段循环播放的透明视频变成一个悬浮在桌面上的角色，始终置顶，在所有桌面空间（Space）都可见。角色可以随意拖动；点击透明区域时，点击会直接穿透到下面的窗口。

## 特性

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

从 [Releases](https://github.com/wquguru/cameo/releases)（或最新一次 [CI 构建](https://github.com/wquguru/cameo/actions/workflows/build.yml)）下载 `Cameo-<version>.zip`，解压后将 `Cameo.app` 移到 `/Applications`。

应用使用 ad-hoc 签名，首次启动时请右键点击并选择**打开**。

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

## 准备视频

Cameo 需要带透明通道的 `.mov` 文件。转换现有视频：

```bash
# FFmpeg，通过 VideoToolbox 硬件编码 HEVC with Alpha
ffmpeg -i in.mov -c:v hevc_videotoolbox -alpha_quality 0.75 -pix_fmt bgra -tag:v hvc1 -b:v 6M out.mov

# 或使用 macOS 自带工具
avconvert -s in.mov -o out.mov -p PresetHEVCHighestQualityWithAlpha
```

需要测试素材？运行 `swift run CameoSample sample.mov` 生成一段。

## 开发

```bash
swift build               # 调试构建
scripts/build.sh          # 发布版应用，输出到 build/Cameo.app
scripts/package.sh        # 发布版压缩包，输出到 build/Cameo-<version>.zip
```

| 路径 | 用途 |
| --- | --- |
| `Sources/Cameo` | 应用本体（AppKit、SwiftUI 弹窗、AVFoundation 播放） |
| `Sources/CameoSample` | 生成 HEVC 透明示例视频的命令行工具 |
| `Sources/CameoIcon` | 渲染应用图标的命令行工具 |
| `design/` | 设计参考文件（用浏览器打开） |

## 参与贡献

欢迎提交 Issue 和 Pull Request。Cameo 有意保持精简，新增功能前请先开 Issue 讨论。项目范围与约定见 [AGENTS.md](AGENTS.md)。

## 许可证

[Apache License 2.0](LICENSE)
