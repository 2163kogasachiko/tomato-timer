#!/bin/bash
# tauri/src/tomato.png を用意する。
# 引数に利用許諾済みの画像を渡すと中央正方形に切り抜いて配置する。
# 引数なしでは、tomato.png が未生成のときだけ描画の仮画像をコピーする。
set -euo pipefail

tauri_dir="$(cd "$(dirname "$0")/.." && pwd)"
dest="$tauri_dir/src/tomato.png"

if [ $# -ge 1 ]; then
  photo_path="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
  if [ ! -f "$photo_path" ]; then
    echo "画像が見つかりません: $photo_path" >&2
    exit 1
  fi
  if ! python3 -c 'import PIL' 2>/dev/null; then
    echo "Pillowが必要です: python3 -m pip install Pillow" >&2
    exit 1
  fi
  python3 - "$photo_path" "$dest" <<'PY'
from pathlib import Path
from PIL import Image
import sys

source = Image.open(sys.argv[1]).convert("RGBA")
side = min(source.size)
left = (source.width - side) // 2
top = (source.height - side) // 2
photo = source.crop((left, top, left + side, top + side))
photo = photo.resize((1254, 1254), Image.Resampling.LANCZOS)
photo.save(sys.argv[2])
PY
  echo "許諾画像を配置しました: $dest"
else
  if [ -f "$dest" ]; then
    echo "既に存在するため何もしません: $dest"
  else
    cp "$tauri_dir/src/tomato-placeholder.png" "$dest"
    echo "仮画像を配置しました: $dest"
  fi
fi
