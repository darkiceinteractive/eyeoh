#!/usr/bin/env bash
# Regenerates the website's raster brand assets from their SVG sources:
# the 1200x630 social card, the PNG favicons and the Apple touch icon.
# Requires rsvg-convert (brew install librsvg).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_ASSETS="$PROJECT_ROOT/Website/assets"
PUBLIC_ASSETS="$PROJECT_ROOT/Website/public/assets"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert is required (brew install librsvg)." >&2
    exit 1
fi

mkdir -p "$PUBLIC_ASSETS"
CARD_SVG="$(mktemp "${TMPDIR:-/tmp}/eyeoh-card.XXXXXX")"
MENU_B64="$(base64 < "$PUBLIC_ASSETS/eyeoh-demo-menu.png" | tr -d "\n")"
sed "s|@@MENU_PNG@@|$MENU_B64|" "$SITE_ASSETS/social-card.svg" > "$CARD_SVG"
rsvg-convert -w 1200 -h 630 "$CARD_SVG" -o "$PUBLIC_ASSETS/eyeoh-social-card.png"
rm -f "$CARD_SVG"

rsvg-convert -w 32 -h 32 "$SITE_ASSETS/eyeoh-mark.svg" -o "$PUBLIC_ASSETS/favicon-32.png"
rsvg-convert -w 192 -h 192 "$SITE_ASSETS/eyeoh-mark.svg" -o "$PUBLIC_ASSETS/icon-192.png"

# iOS rounds the corners itself and wants an opaque square, so render the mark
# on a full-bleed background rather than the rounded tile.
TOUCH_SVG="$(mktemp "${TMPDIR:-/tmp}/eyeoh-touch.XXXXXX")"
trap 'rm -f "$TOUCH_SVG"' EXIT
cat > "$TOUCH_SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 164 164">
  <rect width="164" height="164" fill="#0a1218"/>
  <g fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="M23 82h35M45 68l14 14-14 14" stroke="#a0ce4e" stroke-width="11"/>
    <path d="M70 75v14M82 59v46M94 69v26" stroke="#f8fafc" stroke-width="10"/>
    <path d="M106 82h35M128 68l14 14-14 14" stroke="#008bb4" stroke-width="11"/>
  </g>
</svg>
SVG
rsvg-convert -w 180 -h 180 "$TOUCH_SVG" -o "$PUBLIC_ASSETS/apple-touch-icon.png"

echo "Generated social card, favicons and Apple touch icon in $PUBLIC_ASSETS"
