#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# version.env is resolved from the repository root at runtime.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

APP_IDENTITY=${APP_IDENTITY:-}
NOTARY_PROFILE=${NOTARY_PROFILE:-}
NOTARIZE=0

if [[ "${1:-}" == "--notarize" ]]; then
    NOTARIZE=1
elif [[ -n "${1:-}" ]]; then
    echo "Usage: $(basename "$0") [--notarize]" >&2
    exit 2
fi

if [[ -z "$APP_IDENTITY" ]]; then
    echo "Set APP_IDENTITY to a Developer ID Application signing identity." >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "$APP_IDENTITY"; then
    echo "Developer ID signing identity not found: $APP_IDENTITY" >&2
    exit 1
fi

"$PROJECT_ROOT/Scripts/build_icon.sh"

SIGNING_MODE=developer-id \
APP_IDENTITY="$APP_IDENTITY" \
APP_ENTITLEMENTS="$PROJECT_ROOT/Config/EyeOh-Direct.entitlements" \
ARCHES="arm64 x86_64" \
DISTRIBUTION_CHANNEL="${DISTRIBUTION_CHANNEL:-direct}" \
POSTHOG_PROJECT_TOKEN="${POSTHOG_PROJECT_TOKEN:-}" \
POSTHOG_HOST="${POSTHOG_HOST:-}" \
SENTRY_DSN="${SENTRY_DSN:-}" \
"$PROJECT_ROOT/Scripts/package_app.sh" release

APP_BUNDLE="$PROJECT_ROOT/build/EyeOh.app"
DSYM_BUNDLE="$PROJECT_ROOT/build/EyeOh.app.dSYM"
DIST_DIR="$PROJECT_ROOT/dist"
ARCHIVE="$DIST_DIR/EyeOh-$MARKETING_VERSION.zip"
mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_BUNDLE" "$ARCHIVE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ -n "${SENTRY_DSN:-}" ]]; then
    if [[ -z "${SENTRY_AUTH_TOKEN:-}" || -z "${SENTRY_ORG:-}" || -z "${SENTRY_PROJECT:-}" ]]; then
        echo "Configured Sentry releases require SENTRY_AUTH_TOKEN, SENTRY_ORG and SENTRY_PROJECT for dSYM upload." >&2
        exit 1
    fi
    if ! command -v sentry-cli >/dev/null 2>&1; then
        echo "sentry-cli is required to upload release dSYMs." >&2
        exit 1
    fi
    sentry-cli debug-files upload --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" "$DSYM_BUNDLE"
fi

if [[ "$NOTARIZE" == "1" ]]; then
    if [[ -z "$NOTARY_PROFILE" ]]; then
        echo "Set NOTARY_PROFILE to a notarytool Keychain profile before notarizing." >&2
        exit 1
    fi

    xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    rm -f "$ARCHIVE"
    ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_BUNDLE" "$ARCHIVE"
    spctl --assess --type execute --verbose=2 "$APP_BUNDLE"

    mkdir -p "$PROJECT_ROOT/Website/public/downloads"
    cp "$ARCHIVE" "$PROJECT_ROOT/Website/public/downloads/EyeOh.zip"
    echo "Notarized website download created at Website/public/downloads/EyeOh.zip"
else
    echo "Created signed release candidate at $ARCHIVE"
    echo "It has not been notarized and was not copied into the public website."
fi

shasum -a 256 "$ARCHIVE"
