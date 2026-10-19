#!/usr/bin/env bash
# Verifies that Website/dist is ready to deploy: the appcast's newest item matches
# version.env, the update archive it references is in dist, and the DMG is present.
# Usage: verify_site_artifacts.sh [--warn]   (--warn reports problems but exits 0)
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

WARN_ONLY=0
if [[ "${1:-}" == "--warn" ]]; then
    WARN_ONLY=1
elif [[ -n "${1:-}" ]]; then
    echo "Usage: $(basename "$0") [--warn]" >&2
    exit 2
fi

SITE_DIR="$PROJECT_ROOT/Website/dist"
APPCAST="$SITE_DIR/updates/appcast.xml"
PROBLEMS=0

fail() {
    echo "verify: $1" >&2
    PROBLEMS=$((PROBLEMS + 1))
}

if [[ ! -f "$APPCAST" ]]; then
    fail "missing $APPCAST (run 'make site' first)"
else
    ITEM_VERSION=$(sed -n 's/.*<sparkle:shortVersionString>\(.*\)<\/sparkle:shortVersionString>.*/\1/p' "$APPCAST" | head -n 1)
    ITEM_BUILD=$(sed -n 's/.*<sparkle:version>\(.*\)<\/sparkle:version>.*/\1/p' "$APPCAST" | head -n 1)
    ITEM_URL=$(sed -n 's/.*<enclosure url="\([^"]*\)".*/\1/p' "$APPCAST" | head -n 1)

    if [[ "$ITEM_VERSION" != "$MARKETING_VERSION" || "$ITEM_BUILD" != "$BUILD_NUMBER" ]]; then
        fail "appcast newest item is $ITEM_VERSION ($ITEM_BUILD), version.env says $MARKETING_VERSION ($BUILD_NUMBER)"
    fi
    if [[ -z "$ITEM_URL" ]]; then
        fail "appcast has no enclosure url"
    else
        ARCHIVE_PATH="$SITE_DIR/updates/$(basename "$ITEM_URL")"
        if [[ ! -s "$ARCHIVE_PATH" ]]; then
            fail "appcast references $ITEM_URL but $ARCHIVE_PATH is missing or empty"
        fi
    fi
fi

if [[ ! -s "$SITE_DIR/downloads/EyeOh.dmg" ]]; then
    fail "missing $SITE_DIR/downloads/EyeOh.dmg"
fi

if [[ "$PROBLEMS" -gt 0 ]]; then
    if [[ "$WARN_ONLY" == "1" ]]; then
        echo "verify: $PROBLEMS problem(s) found (warn-only mode)." >&2
        exit 0
    fi
    exit 1
fi

echo "Site artifacts verified for $MARKETING_VERSION ($BUILD_NUMBER)."
