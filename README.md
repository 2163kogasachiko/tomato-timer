# トマトタイマー

トマトの写真を使ったmacOS用ポモドーロタイマーです。

## ダウンロード

このリポジトリの **Releases** にある最新リリースからダウンロードしてください。

- **macOS**: `TomatoTimer_X.Y_aarch64.dmg`（Apple Silicon）。開いて `TomatoTimer.app` をアプリケーションフォルダへ
- **Windows**: `TomatoTimer_X.Y_x64-setup.exe`（インストーラー）または `TomatoTimer-Windows-vX.Y.exe`（単体）

旧Swift版の `TomatoTimer-Mac-vX.Y.zip` も同じ Releases にあります。

### macOS で「開けません」「壊れています」と表示された場合

配布しているアプリは Apple の公証（有料の開発者証明書による審査）を受けていないため、初回起動時に次のような警告が出ることがあります。ウイルスではなく、macOS の保護機能（Gatekeeper）によるものです。

- 「"TomatoTimer.app" は開いていません。Apple は、…マルウェアが含まれていないことを検証できませんでした。」（v0.2.1 以降）
- 「"TomatoTimer.app" は壊れているため開けません。ディスクイメージを取り出す必要があります。」（v0.2.0 以前の dmg・旧Swift版 zip）

**対処法**

1. `TomatoTimer.app` をアプリケーションフォルダなどに移動し、一度そのまま起動して警告を出す
2. システム設定 → プライバシーとセキュリティ → 「それでも開く」を選んで許可

それでも開けない場合（「壊れている」と表示されるバージョンではこの方法になります）は、ターミナルで次を実行してください。パスは `TomatoTimer.app` を置いた場所に合わせてください。

```bash
xattr -dr com.apple.quarantine /Applications/TomatoTimer.app
```

なお Windows 版も未署名のため SmartScreen の警告が出ます。「詳細情報」→「実行」で起動できます。

## 主な機能

- 作業、短い休憩、長い休憩の時間設定
- 作業と休憩の自動切り替え
- 休憩開始と終了の通知音を別々に選択
- ウィンドウの移動・サイズ変更、終了・Dockへしまうボタン
- トマト画像を使ったウィンドウ、Dock、通知アイコン

## ソースからビルド

macOS 13以降（Apple シリコン、Intel）で動作します。ビルドには Xcode Command Line Tools、Python 3、Pillowが必要です。Adobe Stock画像はリポジトリに含めていません。ご自身が利用許諾を得た画像を指定してください。

```bash
python3 -m pip install Pillow
./build-mac.sh /path/to/licensed-tomato.png
```

完成品は `dist/TomatoTimer-Mac-vX.Y.zip` に出力されます。バージョン番号は git タグ（`v2.9` など）から自動で決まるので、リリース前にタグを打ってください。

## 画像について

配布アプリにはAdobe Stockのトマト画像（アセットID: 577240549）を使用しています。Adobe Stockの利用条件に従い、画像ファイル単体はこのリポジトリに含めていません。ソースからビルドする場合は、ご自身で利用許諾を得た画像を用意してください。

音声ファイルはこのプロジェクト用に作成したオリジナル音です。「おもちゃ風マーチ」は既存楽曲の録音や複製ではありません。
