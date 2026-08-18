#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# version.env is resolved from the repository root at runtime.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

if ! grep -Fq "Version $MARKETING_VERSION" "$PROJECT_ROOT/Website/src/pages/index.astro"; then
    echo "Website version does not match MARKETING_VERSION=$MARKETING_VERSION." >&2
    exit 1
fi

if ! grep -Fq "## $MARKETING_VERSION" "$PROJECT_ROOT/CHANGELOG.md"; then
    echo "Changelog has no section for $MARKETING_VERSION." >&2
    exit 1
fi

if ! grep -Fq "NSBluetoothAlwaysUsageDescription" "$PROJECT_ROOT/Scripts/package_app.sh"; then
    echo "Packaged builds are missing the Bluetooth purpose string." >&2
    exit 1
fi

if ! grep -Fq 'exact: "2.9.5"' "$PROJECT_ROOT/Package.swift"; then
    echo "Direct updater is not pinned to the reviewed Sparkle release." >&2
    exit 1
fi

if ! grep -Fq 'DISTRIBUTION_CHANNEL=mas' "$PROJECT_ROOT/Scripts/build_mas_candidate.sh"; then
    echo "MAS channel build script is missing." >&2
    exit 1
fi

if ! grep -Fq 'SPARKLE_FEED_URL=https://eyeoh.app/updates/appcast.xml' "$PROJECT_ROOT/Config/EyeOh-Update.conf"; then
    echo "Sparkle feed URL is missing or unexpected." >&2
    exit 1
fi

for ENTITLEMENTS in \
    "$PROJECT_ROOT/Config/EyeOh-Direct.entitlements" \
    "$PROJECT_ROOT/Config/EyeOh-MAS.entitlements"; do
    if ! grep -Fq "com.apple.security.device.bluetooth" "$ENTITLEMENTS"; then
        echo "Bluetooth entitlement missing from $ENTITLEMENTS." >&2
        exit 1
    fi
done

echo "Release metadata matches version $MARKETING_VERSION."
