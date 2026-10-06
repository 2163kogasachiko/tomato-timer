# AGENTS.md

トマトタイマー（macOS用ポモドーロタイマー）のリポジトリで作業するエージェント向けのメモです。

## 構成

- `TomatoTimer.swift`: アプリ本体（SwiftUI / AppKit / AVFoundation、単一ファイル）
- `build-mac.sh`: `.app` の組み立て、署名、zip化を行うビルドスクリプト
- `timer-*.wav`: 通知音（オリジナル音源）

## ビルド

macOS 13以降、Xcode Command Line Tools、Python 3、Pillowが必要です。

```bash
./build-mac.sh /path/to/licensed-tomato.png
```

出力は `dist/TomatoTimer-Mac-v<バージョン>.zip` です。`dist/` はコミットしません。

## 画像の扱い

- Adobe Stockのトマト画像（アセットID: 577240549）はリポジトリに含めません。`tomato-cutout.png` と `TomatoTimer.icns` もコミットしません。
- 許諾済みの画像が手元にない場合、仮画像でビルドして動作確認してもかまいません。ただし、その zip は配布に使わず、仮画像であることを報告してください。

## バージョン更新

バージョンを上げるときは、次の箇所を揃えて変更します。

- `build-mac.sh` の `CFBundleShortVersionString` と `CFBundleVersion`
- `build-mac.sh` の zip ファイル名
- `README.md` のダウンロード名と出力先

## Git

- `main` に直接コミットせず、作業ブランチを切ってください。
- `origin`（`2163kogasachiko/tomato-timer`）には書き込み権限がない場合があります。その場合はフォークにプッシュし、`origin` へプルリクエストを出してください。
