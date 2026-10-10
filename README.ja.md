<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Cameo のアイコン">
</p>

<h1 align="center">Cameo</h1>

<p align="center">
  透明なキャラクター動画をデスクトップに置く、小さな macOS メニューバーアプリ。
</p>

<p align="center">
  <a href="https://github.com/wquguru/cameo/actions/workflows/build.yml"><img src="https://github.com/wquguru/cameo/actions/workflows/build.yml/badge.svg" alt="ビルド"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="ライセンス: Apache-2.0"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a></p>

---

Cameo は、アルファチャンネル付きのループ動画を、すべてのウインドウと操作スペースの最前面に浮かぶキャラクターとして再生します。キャラクターはどこへでもドラッグでき、透明なピクセルのクリックはそのまま下にあるものへ通り抜けます。

## 特長

- **猫が最初から入っています** — Chaofei は作者の飼い猫をモデルに、コードで描かれたシルバータビーのブリティッシュショートヘア。画面の下端をうろうろ歩き回り、歩く、座る、寝そべってうたた寝する、立ち上がる、転がる、といった動きをします。クリックすると転がり、ドラッグすると持ち上げられます。ポップオーバーから動作を固定することもできます。
- **本当に透明** — マウスに反応するのはキャラクターの見えているピクセルだけで、それ以外はすべてクリックが通り抜けます。
- **常に最前面** — すべての操作スペースで、すべてのウインドウの上に浮かびます。
- **ネイティブ形式** — HEVC with Alpha と ProRes 4444（`.mov`）を AVFoundation でデコード。FFmpeg も同梱コーデックも不要です。
- **省リソース** — フルスクリーンのアプリに隠れているときや画面がスリープしているときは一時停止し、バッテリー駆動時は 30 fps に制限します。
- **ミニマル** — メニューバーのポップオーバーと、シンプルなキャラクターライブラリだけ。設定項目も依存ライブラリもありません。

## 動作環境

- macOS 14 Sonoma 以降（Apple シリコンまたは Intel）
- ソースからビルドする場合：Xcode コマンドラインツール（`xcode-select --install`）

## インストール

### ダウンロード

[Releases](https://github.com/wquguru/cameo/releases) から **`Cameo-<version>-macOS-Universal.dmg`** をダウンロードしてください。macOS 14 以降を搭載した Apple シリコン Mac と Intel Mac の両方に対応する、ひとつのインストーラです。開いて **Cameo** を「**アプリケーション**」にドラッグします。隣にはアプリ単体の `.zip` と `checksums.txt`（SHA-256）も置いてあります。

このアプリはアドホック署名です（公証は受けていません）。初回起動時に macOS がブロックするので、「**システム設定 › プライバシーとセキュリティ**」を開いて「**このまま開く**」をクリックするか、`xattr -dr com.apple.quarantine /Applications/Cameo.app` を実行してください。

### アップデートと言語

Cameo は毎日アップデートを確認し、ポップオーバーから自分自身をアップデートできます。11 の言語に対応し、Mac の言語に従います。別の言語を選ぶには、ポップオーバーの「**言語**」を使ってください。

### ソースからビルド

```bash
git clone https://github.com/wquguru/cameo.git
cd cameo
scripts/build.sh          # → build/Cameo.app
open build/Cameo.app
```

### アンインストール

ポップオーバーで「ログイン時に開く」をオフにし、Cameo を終了してゴミ箱に入れます。読み込んだキャラクターと設定は残るので、`~/Library/Application Support/Cameo` を削除し、`defaults delete io.github.wquguru.cameo` を実行すると消えます。

## 使い方

1. メニューバーの Cameo アイコン（画面から顔をのぞかせる人の形）をクリックします。
2. **+** で動画を追加するか、ポップオーバーに動画をドロップするか、Finder で「**このアプリケーションで開く → Cameo**」を選びます。
3. キャラクターを選び、好きな場所へドラッグします。

メニューバーが混んでアイコンがノッチに隠れたときは、Cameo をもう一度開く（Spotlight や Launchpad）か、キャラクターを右クリックすると同じポップオーバーが開きます。

キャラクターを非表示にしている間は Cameo が Dock にも表示されます。クリックするとポップオーバーが開き、ビデオをドロップすると追加できます。

キャラクターが増えてきたら、ライブラリを開いて検索、名前の変更、削除ができます。読み込んだ動画は `~/Library/Application Support/Cameo/Characters` にコピーされます。

## キャラクター

### ギャラリー

**[wquguru.github.io/cameo](https://wquguru.github.io/cameo/)** で無料のキャラクターを探して **Add to Cameo** をクリックすると、アプリがキャラクターをダウンロードして切り替えます（`cameo://add?url=…` リンク経由）。

### キャラクターを作る

キャラクターは、アルファ付きでループする `.mov`（HEVC with Alpha または ProRes 4444）ひとつです。いちばん簡単なのは、同梱のスキルを使ってコーディングエージェントに作らせる方法です：

| 手元にあるもの | スキル |
| --- | --- |
| グリーンバックの動画、またはアルファ付きの動画 | [`cameo-from-video`](skills/cameo-from-video/SKILL.md) |
| 説明文だけ（OpenRouter の API キーが必要） | [`cameo-image-loop`](skills/cameo-image-loop/SKILL.md) |

```bash
npx skills add wquguru/cameo --skill cameo-from-video  # 動画から
npx skills add wquguru/cameo --skill cameo-image-loop  # 説明文から
```

あとは *「~/Downloads/dance.mp4 を Cameo のキャラクターにして」* や *「Cameo のキャラクターを作って：黄色いサンドレスの女性、座って手を振る」* のように頼むだけ。結果を確認して Cameo に追加してくれます。

気に入ったものができたら、[ギャラリーにアップロード](https://wquguru.github.io/cameo/#submit)して審査を受けてください。

## 開発

```bash
swift build                        # debug build
scripts/build.sh                   # release app bundle in build/Cameo.app
swift run CameoSample sample.mov   # a test clip with alpha
```

プロジェクト構成、パッケージング、リリースについては [AGENTS.md](AGENTS.md) を参照してください。

## コントリビュート

Issue やプルリクエストを歓迎します。Cameo は意図的に小さく保っているため、UI を追加する前に Issue を立てて新機能について相談してください。

## ライセンス

[Apache License 2.0](LICENSE)
