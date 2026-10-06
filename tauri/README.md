# Tauri プロトタイプ

Windows / macOS マルチプラットフォーム化の可否を検証するための試作です。本実装ではありません。

検証の主眼は「透過・飾りなしウィンドウにトマト画像を表示する」見た目が Windows の WebView2 でも成立するかの確認です。

## 内容

- `src/index.html` — 透過ウィンドウ上のトマト＋タイマー画面。ドラッグ移動、独自の閉じる/最小化ボタン、開始/一時停止/リセット、フェーズ切り替え、通知音、設定シート（分数・通知音・試聴、localStorage に永続化）
- `src-tauri/` — Tauri v2。`transparent: true` / `decorations: false` / `shadow: false` / 最小サイズ 300×310
- タイマーはフロントエンドの JS で動く簡易版（本実装ではスロットリング対策として Rust 側で駆動する想定）

## 注意

- `src/tomato-placeholder.png` は `DrawnTomato` を再現した描画トマトです。許諾画像（Adobe Stock 577240549）は使っていません。このビルドは配布しないでください
- 通知パネルは未実装です

## ローカルで試す

```bash
cd tauri
npm install
npm run dev      # 開発起動
npm run build    # リリースビルド
```

Windows では Rust（rustup）と Node.js が必要です。WebView2 は Windows 11 標準搭載です。

## CI の成果物で試す（実機にツールを入れなくてよい）

`feat/tauri-proto` ブランチへの push、または Actions タブからの手動実行で `Build Tauri prototype` が走ります。完了したら Artifacts から：

- `tomato-timer-tauri-windows-exe` — 単体 exe（未署名のため SmartScreen が出ます。「詳細情報」→「実行」）
- `tomato-timer-tauri-windows-nsis` — NSIS インストーラー
- `tomato-timer-tauri-macos-dmg` — macOS 用 dmg（Apple Silicon、未署名なので右クリック→開く）

## Windows で確認したいこと

- 透明な背景の上にトマトだけが見えるか（白背景や黒縁が出ないか）
- リサイズ時にチラつき・残像・境界のアーティファクトが出ないか
- トマトのドラッグでウィンドウが移動するか
- 独自の閉じる/最小化ボタンが効くか
- DPI の異なるディスプレイ間の移動で表示が崩れないか
