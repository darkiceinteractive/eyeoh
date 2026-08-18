#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE=${1:-}
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
    echo "Usage: $(basename "$0") /path/to/notarized-EyeOh.zip" >&2
    exit 2
fi

# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/Config/EyeOh-Update.conf"

TOOLS_DIR=$("$PROJECT_ROOT/Scripts/bootstrap_sparkle_tools.sh")
KEY_PUBLIC=$(
    "$TOOLS_DIR/bin/generate_keys" --account "$SPARKLE_KEY_ACCOUNT" -p \
        | tail -n 1 \
        | tr -d '[:space:]'
)
if [[ "$KEY_PUBLIC" != "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "The Sparkle key in Keychain does not match Config/EyeOh-Update.conf." >&2
    exit 1
fi

UPDATES_DIR="$PROJECT_ROOT/Website/public/updates"
VERSIONED_NAME="EyeOh-$MARKETING_VERSION-$BUILD_NUMBER.zip"
mkdir -p "$UPDATES_DIR"
cp "$ARCHIVE" "$UPDATES_DIR/$VERSIONED_NAME"

"$TOOLS_DIR/bin/generate_appcast" \
    --account "$SPARKLE_KEY_ACCOUNT" \
    --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
    --link "https://eyeoh.app/" \
    --maximum-versions 5 \
    --maximum-deltas 3 \
    -o "$UPDATES_DIR/appcast.xml" \
    "$UPDATES_DIR"

echo "Prepared signed update archive and appcast in $UPDATES_DIR"
echo "Deploy the archive and deltas before appcast.xml. Nothing was deployed by this script."
