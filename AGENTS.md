# AGENTS.md

トマトタイマー（macOS用ポモドーロタイマー）のリポジトリで作業するエージェント向けのメモです。

## 最初に読むファイル

| ファイル | 内容 | 読むとき |
| --- | --- | --- |
| `REQUIREMENT.md` | アプリの仕様と既知の課題 | 機能の追加・変更の前に必ず |
| `TomatoTimer.swift` | アプリ本体（単一ファイル） | コードを変えるとき |
| `build-mac.sh` | `.app` の組み立て、署名、zip化 | ビルド、バージョン更新、リソース追加のとき |
| `README.md` | 利用者向けの説明 | 機能や配布物の説明が変わるとき |

## ファイル一覧

| ファイル | 役割 | 備考 |
| --- | --- | --- |
| `TomatoTimer.swift` | タイマーのロジック（`TimerModel`）、画面（`ContentView`）、ウィンドウ設定、アプリの起動処理 | |
| `build-mac.sh` | 画像の加工、`Info.plist` の生成、コンパイル、署名、zip化 | arm64 と x86_64 を macOS 13 向けに別々にビルドし、`lipo` で Universal にまとめる |
| `timer-chime.wav` / `timer-beeps.wav` / `timer-toy-march.wav` / `timer-bell.wav` | 通知音 | オリジナル音源。ファイル名は `TimerModel.SoundChoice.fileName` と対応 |
| `REQUIREMENT.md` | 仕様 | 仕様を変えたら更新する |
| `README.md` | 利用者向けの説明 | |
| `AGENTS.md` | このファイル | |

### リポジトリにないファイル

次のファイルはコミットしません（`.gitignore` 済み）。

- トマト画像（Adobe Stock、アセットID 577240549）。ビルド時に引数で渡します。
- `tomato-cutout.png`、`TomatoTimer.icns`。ビルド時に画像から作られます。
- `dist/`、`*.app`、`*.zip`。ビルドの出力です。

## ビルド

macOS 13以降、Xcode Command Line Tools、Python 3、Pillowが必要です。

```bash
./build-mac.sh /path/to/licensed-tomato.png
```

出力は `dist/TomatoTimer-Mac-v<バージョン>.zip` です。

許諾済みの画像が手元にない場合は、仮画像でビルドして動作確認してもかまいません。ただし、その zip は配布に使わず、仮画像であることを報告してください。

## 変更するときの注意

- 仕様が変わる変更では、`REQUIREMENT.md` も同じコミットで更新してください。
- 通知音を追加・変更するときは、wav ファイルと `TimerModel.SoundChoice` の両方を揃えてください。`build-mac.sh` は `timer-*.wav` をまとめてコピーします。
- バージョンは git タグ（`vX.Y` 形式、GitHub Releases と対応）で管理します。リリース時はタグを打ってから `build-mac.sh` を実行してください。`CFBundleShortVersionString` と zip ファイル名はタグから、`CFBundleVersion` はビルド時刻から自動生成され、設定画面の表示は `Info.plist` から読むため、ソースやスクリプトを手で書き換える箇所はありません。
- 対応する最低OSを変えるときは、`build-mac.sh` の `min_macos` と `LSMinimumSystemVersion`、`README.md`、`REQUIREMENT.md` を揃えてください。
- ビルド後は `vtool -show-build` で、両方のアーキテクチャの `minos` が対応OSになっているか確認してください。

## Git

- `main` に直接コミットせず、作業ブランチを切ってください。
- `origin`（`2163kogasachiko/tomato-timer`）には書き込み権限がない場合があります。その場合はフォークにプッシュし、`origin` へプルリクエストを出してください。
