#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION=${1:-release}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="EyeOh"
BUNDLE_ID="au.com.darkice.eyeoh"
MINIMUM_MACOS_VERSION="14.0"
SIGNING_MODE=${SIGNING_MODE:-adhoc}
APP_IDENTITY=${APP_IDENTITY:-}
APP_ENTITLEMENTS=${APP_ENTITLEMENTS:-"$PROJECT_ROOT/Config/EyeOh-Direct.entitlements"}
POSTHOG_PROJECT_TOKEN=${POSTHOG_PROJECT_TOKEN:-}
POSTHOG_HOST=${POSTHOG_HOST:-}
SENTRY_DSN=${SENTRY_DSN:-}
DISTRIBUTION_CHANNEL=${DISTRIBUTION_CHANNEL:-source}
MAS_PROVISIONING_PROFILE=${MAS_PROVISIONING_PROFILE:-}
APP_BUILD_ROOT=${APP_BUILD_ROOT:-"$PROJECT_ROOT/build"}
SWIFT_SCRATCH_PATH="$PROJECT_ROOT/.build/channels/$DISTRIBUTION_CHANNEL"

if [[ "$SIGNING_MODE" != "adhoc" && "$SIGNING_MODE" != "developer-id" && "$SIGNING_MODE" != "mas" ]]; then
    echo "SIGNING_MODE must be adhoc, developer-id or mas." >&2
    exit 2
fi
if [[ "$DISTRIBUTION_CHANNEL" != "source" && "$DISTRIBUTION_CHANNEL" != "direct" && "$DISTRIBUTION_CHANNEL" != "mas" ]]; then
    echo "DISTRIBUTION_CHANNEL must be source, direct or mas." >&2
    exit 2
fi

cd "$PROJECT_ROOT"
# version.env is resolved from the repository root at runtime.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"
# Public updater configuration; the private signing key remains in Keychain.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/Config/EyeOh-Update.conf"

if [[ "$SIGNING_MODE" == "developer-id" || "$SIGNING_MODE" == "mas" ]]; then
    if [[ -z "$APP_IDENTITY" ]]; then
        echo "APP_IDENTITY is required for $SIGNING_MODE signing." >&2
        exit 1
    fi
fi

if [[ -n "${ARCHES:-}" ]]; then
    read -r -a ARCH_LIST <<< "$ARCHES"
else
    ARCH_LIST=("$(uname -m)")
fi
BUILD_ARGS=(--scratch-path "$SWIFT_SCRATCH_PATH" -c "$CONFIGURATION")
for ARCH in "${ARCH_LIST[@]}"; do
    BUILD_ARGS+=(--arch "$ARCH")
done
export EYEOH_DISTRIBUTION_CHANNEL="$DISTRIBUTION_CHANNEL"
swift build "${BUILD_ARGS[@]}"
PRODUCT_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
BINARY_SOURCE="$PRODUCT_DIR/$APP_NAME"
for ARCH in "${ARCH_LIST[@]}"; do
    lipo "$BINARY_SOURCE" -verify_arch "$ARCH"
done

APP_BUNDLE="$APP_BUILD_ROOT/$APP_NAME.app"
BINARY_DESTINATION="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_SOURCE" "$BINARY_DESTINATION"
chmod +x "$BINARY_DESTINATION"

if [[ "$DISTRIBUTION_CHANNEL" == "direct" ]]; then
    SPARKLE_FRAMEWORK_SOURCE=$(find "$SWIFT_SCRATCH_PATH/artifacts" -type d -name Sparkle.framework -print -quit)
    if [[ -z "$SPARKLE_FRAMEWORK_SOURCE" ]]; then
        echo "Sparkle.framework was not produced for the direct build." >&2
        exit 1
    fi
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    ditto "$SPARKLE_FRAMEWORK_SOURCE" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
fi

DSYM_BUNDLE="$APP_BUILD_ROOT/$APP_NAME.app.dSYM"
rm -rf "$DSYM_BUNDLE"
if [[ "$CONFIGURATION" == "release" ]]; then
    xcrun dsymutil "$BINARY_DESTINATION" -o "$DSYM_BUNDLE"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key><string>$MINIMUM_MACOS_VERSION</string>
    <key>LSUIElement</key><true/>
    <key>NSCameraUsageDescription</key><string>Camera access is used only to show a live preview while you choose a preferred camera.</string>
    <key>NSCameraUseContinuityCameraDeviceType</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Bluetooth access lets EyeOh reconnect paired audio devices you choose from its menu. EyeOh never pairs new devices automatically.</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Dark Ice Interactive Pty Ltd</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -insert EyeOhDistributionChannel -string "$DISTRIBUTION_CHANNEL" "$APP_BUNDLE/Contents/Info.plist"
if [[ "$DISTRIBUTION_CHANNEL" == "direct" ]]; then
    /usr/bin/plutil -insert SUFeedURL -string "$SPARKLE_FEED_URL" "$APP_BUNDLE/Contents/Info.plist"
    /usr/bin/plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$APP_BUNDLE/Contents/Info.plist"
    /usr/bin/plutil -insert SUScheduledCheckInterval -integer 86400 "$APP_BUNDLE/Contents/Info.plist"
    /usr/bin/plutil -insert SUVerifyUpdateBeforeExtraction -bool true "$APP_BUNDLE/Contents/Info.plist"
fi
if [[ -n "$POSTHOG_PROJECT_TOKEN" && -n "$POSTHOG_HOST" ]]; then
    if [[ "$POSTHOG_HOST" != "https://eu.i.posthog.com" ]]; then
        echo "Official EyeOh builds require POSTHOG_HOST=https://eu.i.posthog.com" >&2
        exit 1
    fi
    /usr/bin/plutil -insert EyeOhPostHogProjectToken -string "$POSTHOG_PROJECT_TOKEN" "$APP_BUNDLE/Contents/Info.plist"
    /usr/bin/plutil -insert EyeOhPostHogHost -string "$POSTHOG_HOST" "$APP_BUNDLE/Contents/Info.plist"
fi
if [[ -n "$SENTRY_DSN" ]]; then
    if [[ "$SENTRY_DSN" != *".ingest.de.sentry.io/"* ]]; then
        echo "Official EyeOh builds require a Sentry EU-region DSN." >&2
        exit 1
    fi
    /usr/bin/plutil -insert EyeOhSentryDSN -string "$SENTRY_DSN" "$APP_BUNDLE/Contents/Info.plist"
fi

if [[ -f "$PROJECT_ROOT/Icon.icns" ]]; then
    cp "$PROJECT_ROOT/Icon.icns" "$APP_BUNDLE/Contents/Resources/Icon.icns"
fi
PRIVACY_MANIFEST="$PROJECT_ROOT/Config/EyeOh-PrivacyInfo-Offline.xcprivacy"
if [[ -n "$SENTRY_DSN" || ( -n "$POSTHOG_PROJECT_TOKEN" && -n "$POSTHOG_HOST" ) ]]; then
    PRIVACY_MANIFEST="$PROJECT_ROOT/Config/EyeOh-PrivacyInfo.xcprivacy"
fi
cp "$PRIVACY_MANIFEST" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/THIRD_PARTY_NOTICES.md"
if [[ "$DISTRIBUTION_CHANNEL" == "direct" ]]; then
    cp "$PROJECT_ROOT/Config/Sparkle-LICENSE.txt" "$APP_BUNDLE/Contents/Resources/Sparkle-LICENSE.txt"
fi

EFFECTIVE_ENTITLEMENTS="$APP_ENTITLEMENTS"
if [[ "$SIGNING_MODE" == "mas" ]]; then
    if [[ -z "$MAS_PROVISIONING_PROFILE" || ! -f "$MAS_PROVISIONING_PROFILE" ]]; then
        echo "MAS_PROVISIONING_PROFILE must point to the EyeOh Mac App Store profile." >&2
        exit 1
    fi

    cp "$MAS_PROVISIONING_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"
    PROFILE_PLIST="$APP_BUILD_ROOT/EyeOh-MAS-profile.plist"
    EFFECTIVE_ENTITLEMENTS="$APP_BUILD_ROOT/EyeOh-MAS-effective.entitlements"
    security cms -D -i "$MAS_PROVISIONING_PROFILE" > "$PROFILE_PLIST"
    cp "$APP_ENTITLEMENTS" "$EFFECTIVE_ENTITLEMENTS"

    PROFILE_APP_IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$PROFILE_PLIST")
    PROFILE_TEAM_IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' "$PROFILE_PLIST")
    if [[ "$PROFILE_APP_IDENTIFIER" != *".$BUNDLE_ID" ]]; then
        echo "Provisioning profile is for $PROFILE_APP_IDENTIFIER, not $BUNDLE_ID." >&2
        exit 1
    fi
    /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $PROFILE_APP_IDENTIFIER" "$EFFECTIVE_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $PROFILE_TEAM_IDENTIFIER" "$EFFECTIVE_ENTITLEMENTS"
fi

xattr -cr "$APP_BUNDLE"

if [[ "$DISTRIBUTION_CHANNEL" == "direct" ]]; then
    SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    SPARKLE_VERSION_ROOT="$SPARKLE_FRAMEWORK/Versions/B"
    if [[ "$SIGNING_MODE" == "developer-id" ]]; then
        codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" "$SPARKLE_VERSION_ROOT/XPCServices/Installer.xpc"
        codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" --preserve-metadata=entitlements "$SPARKLE_VERSION_ROOT/XPCServices/Downloader.xpc"
        codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" "$SPARKLE_VERSION_ROOT/Autoupdate"
        codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" "$SPARKLE_VERSION_ROOT/Updater.app"
        codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" "$SPARKLE_FRAMEWORK"
    else
        codesign --force --sign - "$SPARKLE_VERSION_ROOT/XPCServices/Installer.xpc"
        codesign --force --sign - --preserve-metadata=entitlements "$SPARKLE_VERSION_ROOT/XPCServices/Downloader.xpc"
        codesign --force --sign - "$SPARKLE_VERSION_ROOT/Autoupdate"
        codesign --force --sign - "$SPARKLE_VERSION_ROOT/Updater.app"
        codesign --force --sign - "$SPARKLE_FRAMEWORK"
    fi
fi

if [[ "$SIGNING_MODE" == "developer-id" || "$SIGNING_MODE" == "mas" ]]; then
    codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" --entitlements "$EFFECTIVE_ENTITLEMENTS" "$APP_BUNDLE"
else
    codesign --force --sign - --entitlements "$EFFECTIVE_ENTITLEMENTS" "$APP_BUNDLE"
fi

echo "Created $APP_BUNDLE"
if [[ -d "$DSYM_BUNDLE" ]]; then
    echo "Created $DSYM_BUNDLE"
fi
