#!/bin/zsh
# 配布用ビルド。許諾済みのトマト画像を引数に渡す。
#   ./build-release.sh /path/to/licensed-tomato.png
#
# git タグ vX.Y と tauri.conf.json の version が一致することを確認してから
# `npm run build` を実行する。出力は src-tauri/target/release/bundle/ 以下。
set -euo pipefail

if [[ $# -lt 1 || ! -f "$1" ]]; then
  echo "使い方: ./build-release.sh /path/to/licensed-tomato.png" >&2
  exit 1
fi

tauri_dir="${0:A:h}"
repo_dir="${tauri_dir:h}"

tag_version="$(git -C "$repo_dir" describe --tags --match 'v*' --abbrev=0 2>/dev/null || true)"
tag_version="${tag_version#v}"
if [[ -z "$tag_version" ]]; then
  echo "git タグが見つかりません。リリースには vX.Y 形式のタグを打ってください。" >&2
  exit 1
fi

conf_version="$(grep -o '"version": *"[^"]*"' "$tauri_dir/src-tauri/tauri.conf.json" | head -1 | cut -d'"' -f4)"
if [[ "$conf_version" != "$tag_version" ]]; then
  echo "tauri.conf.json の version ($conf_version) が git タグ ($tag_version) と一致しません。" >&2
  echo "リリース前に tauri.conf.json の version を更新してください。" >&2
  exit 1
fi

"$tauri_dir/scripts/prepare-tomato.sh" "$1"
cd "$tauri_dir"
npx tauri icon src/tomato.png -o src-tauri/icons
npm install
npm run build
echo "完成: $tauri_dir/src-tauri/target/release/bundle/"
