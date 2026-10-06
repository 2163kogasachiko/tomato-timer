# Tauri 版トマトタイマー

Tauri v2 による macOS / Windows マルチプラットフォーム版です。こちらが本体の実装です（リポジトリ直下の `TomatoTimer.swift` は旧macOS専用のレガシー実装）。

## 構成

- `src-tauri/src/lib.rs` — タイマーのロジック（フェーズ遷移・終了時刻基準の計時・完了数）、Tauri コマンド、通知ウィンドウの生成、音声再生（rodio）、設定の保存（`settings.json`）
  - 計時は Rust 側スレッドが駆動します。ウィンドウを最小化・遮蔽してフロントエンドがスロットルされても残り時間はずれません
  - 音声も専用スレッドで鳴らします（rodio の型が Send/Sync でないため）
  - macOS のみ、通知ウィンドウに `collectionBehavior` を設定する小さな objc シムあり（全スペース＋フルスクリーン上・非アクティブ表示のため）
- `src/index.html` — メイン画面。`get_state` / `timer-state` イベントで状態を受け取って描画し、ボタン操作はコマンドを invoke するだけ
- `src/notification.html` — 通知パネル。起動時に `get_notification` コマンドで表示内容を取得
- `src/tomato.png` — トマト画像（git 管理外。`scripts/prepare-tomato.sh` が生成）
- `src/tomato-placeholder.png` — 描画トマトの仮画像（git 管理）
- `src-tauri/assets/timer-*.wav` — 通知音。`include_bytes!` でバイナリに埋め込み

## 開発

```bash
cd tauri
npm install
./scripts/prepare-tomato.sh   # 初回のみ（仮画像を配置）
npm run dev                   # 開発起動
npm run build                 # リリースビルド
```

## トマト画像

許諾済みの画像（Adobe Stock 577240549）はリポジトリに含めません。

- `./scripts/prepare-tomato.sh /path/to/image.png` — 中央正方形に切り抜いて `src/tomato.png` を生成
- `./scripts/prepare-tomato.sh`（引数なし） — `tomato.png` が無ければ仮画像をコピー
- 配布ビルドは `./build-release.sh /path/to/licensed-tomato.png`（画像→アイコン→`npm run build`、version と git タグの一致も確認）
- `tomato.png` が無い場合は表示側が仮画像にフォールバックします

## CI とリリース

`.github/workflows/tauri-build.yml` が `main` / `feat/**` への push で Windows（単体exe・NSIS）と macOS（dmg）をビルドします。

- `tomato-timer-windows-exe` — 単体 exe（SmartScreen →「詳細情報」→「実行」）
- `tomato-timer-windows-nsis` — NSIS インストーラー
- `tomato-timer-macos-dmg` — macOS dmg（Apple Silicon）

### GitHub Release

`vX.Y` 形式のタグを push すると、両 OS のビルド成功後に GitHub Release `TomatoTimer vX.Y` が自動作成され、単体 exe・NSIS インストーラー・dmg が添付されます。リリースノートは直前の `v*` タグからのコミット一覧から自動生成されます。

```bash
# src-tauri/tauri.conf.json の version を上げてコミットしてから
git tag v0.2.0
git push fork v0.2.0   # リリースはタグをpushしたリポジトリに作られます
```

タグ名と `tauri.conf.json` の `version` が一致しない場合、ビルドは冒頭で失敗します。成果物は仮画像入り・未署名です。許諾画像で作りたい場合はローカルで `./build-release.sh /path/to/image.png` を使い、`gh release upload` でアセットを差し替えてください。

macOS 版は未署名のため、ブラウザでダウンロードした dmg から起動すると「壊れているため開けません」と出ます。対処は次のどれかです。

- `.app` をデスクトップ等にコピーしたあと `xattr -dr com.apple.quarantine <.appのパス>` を実行
- `gh run download` や `curl` など CLI でダウンロードする（quarantine が付かず、そのまま開けます）
- `npm run build` でローカルビルドする

## 残っている差分・既知の制約

- Windows の通知パネルは表示時にフォーカスを取る可能性があります（macOS 側は `orderFrontRegardless` で非アクティブ化済み）
- 通知パネルの表示位置はプライマリディスプレイ基準です
- 完了した作業数は再起動で0に戻ります（保存しません。本家と同じ）
