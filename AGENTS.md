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
| `TomatoTimer.swift` | 旧macOS専用実装（タイマー・画面・ウィンドウ設定・起動処理） | レガシー。新規開発は `tauri/` 側です |
| `build-mac.sh` | 旧macOS専用ビルド（画像加工、`Info.plist`、コンパイル、署名、zip化） | レガシー。arm64/x86_64 を `lipo` で Universal にまとめる。Tauri 版は `tauri/build-release.sh` |
| `timer-chime.wav` / `timer-beeps.wav` / `timer-toy-march.wav` / `timer-bell.wav` | 通知音（旧Swift版用） | オリジナル音源。Tauri版は `tauri/src-tauri/assets/` の複製を使います。音を追加・変更するときは両方を揃えてください |
| `REQUIREMENT.md` | 仕様 | 仕様を変えたら更新する |
| `README.md` | 利用者向けの説明 | |
| `AGENTS.md` | このファイル | |
| `tauri/` | Tauri v2 版アプリ本体（macOS / Windows） | 詳しくは `tauri/README.md` |
| `tauri/src-tauri/src/lib.rs` | タイマーのロジック、コマンド、通知ウィンドウ、音声再生、設定の保存 | |
| `tauri/src/index.html` | メイン画面 | |
| `tauri/src/notification.html` | 通知パネル | |
| `tauri/scripts/prepare-tomato.sh` | `tauri/src/tomato.png` の生成（許諾画像の切り抜き or 仮画像） | |
| `tauri/build-release.sh` | 配布ビルド（画像→アイコン→`npm run build`） | |

### リポジトリにないファイル

次のファイルはコミットしません（`.gitignore` 済み）。

- トマト画像（Adobe Stock、アセットID 577240549）。ビルド時に引数で渡します。
- `tomato-cutout.png`、`TomatoTimer.icns`。ビルド時に画像から作られます。
- `dist/`、`*.app`、`*.zip`。ビルドの出力です。

## ビルド

### Tauri 版（本体）

Rust（rustup）、Node.js、npm が必要です。開発中は：

```bash
cd tauri
npm install
./scripts/prepare-tomato.sh   # 初回のみ（仮画像が入ります）
npm run dev                   # 開発起動
```

配布ビルドは許諾済みの画像を指定します。`tauri.conf.json` の `version` が git タグと一致している必要があります。

```bash
cd tauri
./build-release.sh /path/to/licensed-tomato.png
```

出力は `tauri/src-tauri/target/release/bundle/` 以下です。Windows 向けは Windows 機上で同じ手順を実行するか、GitHub Actions（`tauri-build.yml`）の成果物を使います（仮画像・未署名のため検証用）。

### 旧macOS専用ビルド（レガシー）

macOS 13以降、Xcode Command Line Tools、Python 3、Pillowが必要です。

```bash
./build-mac.sh /path/to/licensed-tomato.png
```

出力は `dist/TomatoTimer-Mac-v<バージョン>.zip` です。

許諾済みの画像が手元にない場合は、仮画像でビルドして動作確認してもかまいません。ただし、その成果物は配布に使わず、仮画像であることを報告してください。

## 変更するときの注意

- 仕様が変わる変更では、`REQUIREMENT.md` も同じコミットで更新してください。
- 通知音を追加・変更するときは、wav ファイルと `TimerModel.SoundChoice` の両方を揃えてください。`build-mac.sh` は `timer-*.wav` をまとめてコピーします。
- バージョンは git タグ（`vX.Y.Z` 形式、GitHub Releases と対応）が正です。**リリース時は必ずタグを打ってください**（`v*` タグの push で CI が GitHub Release を自動作成します）。Tauri 版は `tauri/src-tauri/tauri.conf.json` の `version` をタグに合わせてコミットします（CI と `build-release.sh` が一致を確認します）。旧 `build-mac.sh` はタグから `Info.plist` と zip 名を自動生成します。
- 採番ルール：大幅な機能追加は `Y` を上げます（例 `v0.1.0` → `v0.2.0`）、小規模な修正は `Z` を上げます（例 `v0.2.0` → `v0.2.1`）。`v1.0.0`（X=1）にするのはまだ尚早です。
- 対応する最低OSを変えるときは、`build-mac.sh` の `min_macos` と `LSMinimumSystemVersion`、`README.md`、`REQUIREMENT.md` を揃えてください。
- ビルド後は `vtool -show-build` で、両方のアーキテクチャの `minos` が対応OSになっているか確認してください。

## Git

- `main` に直接コミットせず、作業ブランチを切ってください。
- `origin`（`2163kogasachiko/tomato-timer`）には書き込み権限がない場合があります。その場合はフォークにプッシュし、`origin` へプルリクエストを出してください。
