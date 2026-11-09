#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
demo_root=${EYEOH_DEMO_OUTPUT:-"$root/build/demo"}
if [[ -e "$demo_root/EyeOh.app" ]]; then
    echo "A demo app already exists. Set EYEOH_DEMO_OUTPUT to a fresh directory for another build." >&2
    exit 1
fi

DISTRIBUTION_CHANNEL=source SIGNING_MODE=adhoc EYEOH_BUILD_DEMO=1 \
POSTHOG_PROJECT_TOKEN='' POSTHOG_HOST='' SENTRY_DSN='' APP_BUILD_ROOT="$demo_root" \
    "$root/Scripts/package_app.sh" release

app="$demo_root/EyeOh.app"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier au.com.darkice.eyeoh.demo' "$plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleDisplayName EyeOh Demo' "$plist"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf 'Open: open -n "%s"\nUnplugged camera: open -n "%s" --args --camera-disconnected\n' "$app" "$app"
