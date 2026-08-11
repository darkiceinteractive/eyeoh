#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $(basename "$0") /path/to/EyeOh.app /path/to/EyeOh.dmg" >&2
    exit 2
fi

APP_BUNDLE=$1
OUTPUT_DMG=$2

if [[ ! -d "$APP_BUNDLE" || "$(basename "$APP_BUNDLE")" != "EyeOh.app" ]]; then
    echo "Expected an EyeOh.app bundle: $APP_BUNDLE" >&2
    exit 1
fi

DMG_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eyeoh-dmg.XXXXXX")"
DMG_STAGING_DIR="$DMG_TEMP_DIR/EyeOh"
cleanup() {
    rm -rf "$DMG_TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$DMG_STAGING_DIR" "$(dirname "$OUTPUT_DMG")"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_STAGING_DIR/EyeOh.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

rm -f "$OUTPUT_DMG"
/usr/bin/hdiutil create \
    -volname "EyeOh" \
    -srcfolder "$DMG_STAGING_DIR" \
    -format UDZO \
    -ov \
    "$OUTPUT_DMG"

echo "Created $OUTPUT_DMG"
