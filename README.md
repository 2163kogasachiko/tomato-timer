# トマトタイマー

トマトの写真を使ったmacOS用ポモドーロタイマーです。

## ダウンロード

このリポジトリの **Releases** にある最新リリースからダウンロードしてください。

- **macOS**: `TomatoTimer_X.Y_aarch64.dmg`（Apple Silicon）。開いて `TomatoTimer.app` をアプリケーションフォルダへ
- **Windows**: `TomatoTimer_X.Y_x64-setup.exe`（インストーラー）または `TomatoTimer-Windows-vX.Y.exe`（単体）

旧Swift版の `TomatoTimer-Mac-vX.Y.zip` も同じ Releases にあります。

未署名のアプリのため、初回起動時に「壊れているため開けません」「開発者を確認できません」と表示されることがあります。その場合は `TomatoTimer.app` をアプリケーションフォルダなどに移動したあと、ターミナルで次を実行してください。

```bash
xattr -dr com.apple.quarantine /Applications/TomatoTimer.app
```

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
