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

cd "$PROJECT_ROOT"
# version.env is resolved from the repository root at runtime.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

if [[ -n "${ARCHES:-}" ]]; then
    read -r -a ARCH_LIST <<< "$ARCHES"
else
    ARCH_LIST=("$(uname -m)")
fi
for ARCH in "${ARCH_LIST[@]}"; do
    swift build -c "$CONFIGURATION" --arch "$ARCH"
done

APP_BUNDLE="$PROJECT_ROOT/build/$APP_NAME.app"
BINARY_DESTINATION="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

BINARY_SOURCES=()
for ARCH in "${ARCH_LIST[@]}"; do
    BINARY_SOURCES+=("$PROJECT_ROOT/.build/$ARCH-apple-macosx/$CONFIGURATION/$APP_NAME")
done

if [[ ${#BINARY_SOURCES[@]} -gt 1 ]]; then
    lipo -create "${BINARY_SOURCES[@]}" -output "$BINARY_DESTINATION"
else
    cp "${BINARY_SOURCES[0]}" "$BINARY_DESTINATION"
fi
chmod +x "$BINARY_DESTINATION"

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
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Dark Ice Interactive Pty Ltd</string>
</dict>
</plist>
PLIST

if [[ -f "$PROJECT_ROOT/Icon.icns" ]]; then
    cp "$PROJECT_ROOT/Icon.icns" "$APP_BUNDLE/Contents/Resources/Icon.icns"
fi

xattr -cr "$APP_BUNDLE"

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
    if [[ -z "$APP_IDENTITY" ]]; then
        echo "APP_IDENTITY is required for Developer ID signing." >&2
        exit 1
    fi
    codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
else
    codesign --force --sign - --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
fi

echo "Created $APP_BUNDLE"
