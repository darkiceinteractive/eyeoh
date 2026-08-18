#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

MODE=${1:---local}
if [[ "$MODE" != "--local" && "$MODE" != "--submission" ]]; then
    echo "Usage: $(basename "$0") [--local|--submission]" >&2
    exit 2
fi

"$PROJECT_ROOT/Scripts/build_icon.sh"

if [[ "$MODE" == "--local" ]]; then
    SIGNING_MODE=adhoc \
    APP_ENTITLEMENTS="$PROJECT_ROOT/Config/EyeOh-MAS.entitlements" \
    APP_BUILD_ROOT="$PROJECT_ROOT/build/mas" \
    ARCHES="arm64 x86_64" \
    DISTRIBUTION_CHANNEL=mas \
    "$PROJECT_ROOT/Scripts/package_app.sh" release
else
    MAS_APP_IDENTITY=${MAS_APP_IDENTITY:-}
    MAS_INSTALLER_IDENTITY=${MAS_INSTALLER_IDENTITY:-}
    MAS_PROVISIONING_PROFILE=${MAS_PROVISIONING_PROFILE:-}

    if [[ -z "$MAS_APP_IDENTITY" || -z "$MAS_INSTALLER_IDENTITY" || -z "$MAS_PROVISIONING_PROFILE" ]]; then
        echo "Set MAS_APP_IDENTITY, MAS_INSTALLER_IDENTITY and MAS_PROVISIONING_PROFILE." >&2
        exit 1
    fi
    if [[ "$MAS_APP_IDENTITY" != *"Dark Ice Interactive Pty Ltd"* ]]; then
        echo "Refusing an Apple Distribution identity that is not owned by Dark Ice Interactive Pty Ltd." >&2
        exit 1
    fi
    if ! security find-identity -v -p codesigning | /usr/bin/grep -Fq "$MAS_APP_IDENTITY"; then
        echo "Apple Distribution identity not found: $MAS_APP_IDENTITY" >&2
        exit 1
    fi
    if ! security find-identity -v | /usr/bin/grep -Fq "$MAS_INSTALLER_IDENTITY"; then
        echo "Mac Installer Distribution identity not found: $MAS_INSTALLER_IDENTITY" >&2
        exit 1
    fi

    SIGNING_MODE=mas \
    APP_IDENTITY="$MAS_APP_IDENTITY" \
    APP_ENTITLEMENTS="$PROJECT_ROOT/Config/EyeOh-MAS.entitlements" \
    MAS_PROVISIONING_PROFILE="$MAS_PROVISIONING_PROFILE" \
    APP_BUILD_ROOT="$PROJECT_ROOT/build/mas" \
    ARCHES="arm64 x86_64" \
    DISTRIBUTION_CHANNEL=mas \
    "$PROJECT_ROOT/Scripts/package_app.sh" release

    mkdir -p "$PROJECT_ROOT/dist"
    SUBMISSION_PACKAGE="$PROJECT_ROOT/dist/EyeOh-MAS-$MARKETING_VERSION-$BUILD_NUMBER.pkg"
    productbuild \
        --component "$PROJECT_ROOT/build/mas/EyeOh.app" /Applications \
        --sign "$MAS_INSTALLER_IDENTITY" \
        "$SUBMISSION_PACKAGE"
    pkgutil --check-signature "$SUBMISSION_PACKAGE"
    echo "Created $SUBMISSION_PACKAGE. It has not been uploaded or submitted."
fi

APP_BUNDLE="$PROJECT_ROOT/build/mas/EyeOh.app"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
if otool -L "$APP_BUNDLE/Contents/MacOS/EyeOh" | /usr/bin/grep -Fq Sparkle; then
    echo "MAS candidate unexpectedly links Sparkle." >&2
    exit 1
fi
if /usr/bin/plutil -p "$APP_BUNDLE/Contents/Info.plist" | /usr/bin/grep -Eq 'SUFeedURL|SUPublicEDKey'; then
    echo "MAS candidate unexpectedly contains updater configuration." >&2
    exit 1
fi

echo "Verified MAS channel: sandboxed entitlements, no Sparkle link, no direct-update keys."
