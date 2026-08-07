#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$PROJECT_ROOT/Website/assets/eyeoh-mark.svg"
WORK_DIR="$PROJECT_ROOT/.build/icon"
ICONSET="$WORK_DIR/EyeOh.iconset"

rm -rf "$WORK_DIR"
mkdir -p "$ICONSET"

qlmanage -t -s 1024 -o "$WORK_DIR" "$SOURCE" >/dev/null
MASTER="$WORK_DIR/eyeoh-mark.svg.png"

make_icon() {
    local pixels="$1"
    local name="$2"
    sips -z "$pixels" "$pixels" "$MASTER" --out "$ICONSET/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$PROJECT_ROOT/Icon.icns"
echo "Created $PROJECT_ROOT/Icon.icns"
