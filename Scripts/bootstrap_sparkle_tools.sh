#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/Config/EyeOh-Update.conf"

TOOLS_DIR="$PROJECT_ROOT/.build/sparkle-tools-$SPARKLE_VERSION"
GENERATE_APPCAST="$TOOLS_DIR/bin/generate_appcast"
if [[ -x "$GENERATE_APPCAST" ]]; then
    echo "$TOOLS_DIR"
    exit 0
fi

mkdir -p "$TOOLS_DIR"
ARCHIVE="$PROJECT_ROOT/.build/Sparkle-$SPARKLE_VERSION.tar.xz"
curl --fail --location --silent --show-error \
    "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    --output "$ARCHIVE"
printf '%s  %s\n' "$SPARKLE_DISTRIBUTION_SHA256" "$ARCHIVE" | shasum -a 256 -c - >/dev/null
tar -xf "$ARCHIVE" -C "$TOOLS_DIR"

if [[ ! -x "$GENERATE_APPCAST" ]]; then
    echo "Sparkle tools were not extracted correctly." >&2
    exit 1
fi

echo "$TOOLS_DIR"
