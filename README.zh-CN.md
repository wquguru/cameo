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

Cameo 每天检查一次 GitHub Releases。有新版本时，菜单栏图标会出现一个琥珀色小圆点，弹窗顶部显示**下载**提示，点击打开发布页，用新的 `Cameo.app` 替换旧的即可。

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
scripts/package.sh        # 通用架构的 .dmg、.zip 和 checksums.txt，输出到 build/
```

| 路径 | 用途 |
| --- | --- |
| `Sources/Cameo` | 应用本体（AppKit、SwiftUI 弹窗、AVFoundation 播放） |
| `Sources/CameoSample` | 生成 HEVC 透明示例视频的命令行工具 |
| `Sources/CameoIcon` | 渲染应用图标的命令行工具 |
| `design/` | 设计参考文件（用浏览器打开） |

### 发布

```bash
scripts/release.sh 0.3.0   # 修改 Info.plist 版本号、提交、打 v0.3.0 标签并推送
```

`release` 工作流会构建该标签对应的提交，校验标签与 `Info.plist` 一致，然后把 `.dmg`、`.zip` 和 `checksums.txt` 发布到 GitHub Releases。

## 参与贡献

欢迎提交 Issue 和 Pull Request。Cameo 有意保持精简，新增功能前请先开 Issue 讨论。项目范围与约定见 [AGENTS.md](AGENTS.md)。

## 许可证

[Apache License 2.0](LICENSE)
