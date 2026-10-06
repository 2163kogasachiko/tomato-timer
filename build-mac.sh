#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || ! -f "$1" ]]; then
  echo "使い方: ./build-mac.sh /path/to/licensed-tomato.png" >&2
  exit 1
fi

repo_dir="${0:A:h}"
photo_path="${1:A}"
build_dir="$repo_dir/dist"
temp_dir="$(mktemp -d /private/tmp/tomato-build.XXXXXX)"
trap 'rm -rf "$temp_dir"' EXIT
app_path="$temp_dir/TomatoTimer.app"
resources="$app_path/Contents/Resources"

if ! python3 -c 'import PIL' 2>/dev/null; then
  echo "Pillowが必要です: python3 -m pip install Pillow" >&2
  exit 1
fi

mkdir -p "$app_path/Contents/MacOS" "$resources" "$build_dir"

python3 - "$photo_path" "$resources" <<'PY'
from pathlib import Path
from PIL import Image
import sys

source = Image.open(sys.argv[1]).convert("RGBA")
side = min(source.size)
left = (source.width - side) // 2
top = (source.height - side) // 2
photo = source.crop((left, top, left + side, top + side))
photo = photo.resize((1254, 1254), Image.Resampling.LANCZOS)
output = Path(sys.argv[2])
photo.save(output / "tomato-cutout.png")
photo.save(output / "TomatoTimer.icns", format="ICNS")
PY

cp "$repo_dir"/timer-*.wav "$resources/"

cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>ja</string>
<key>CFBundleDisplayName</key><string>トマトタイマー</string>
<key>CFBundleExecutable</key><string>TomatoTimer</string>
<key>CFBundleIconFile</key><string>TomatoTimer.icns</string>
<key>CFBundleIdentifier</key><string>com.codex.tomatotimer</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>TomatoTimer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.9</string>
<key>CFBundleVersion</key><string>20</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

CLANG_MODULE_CACHE_PATH="$temp_dir/.clang-cache" \
SWIFT_MODULE_CACHE_PATH="$temp_dir/.swift-cache" \
xcrun swiftc -O -parse-as-library "$repo_dir/TomatoTimer.swift" \
  -o "$app_path/Contents/MacOS/TomatoTimer" \
  -framework SwiftUI -framework AppKit -framework AVFoundation

codesign --force --deep --sign - "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$build_dir/TomatoTimer-Mac-v2.9.zip"
echo "完成: $build_dir/TomatoTimer-Mac-v2.9.zip"
