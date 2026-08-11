#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROBE_DIR="$PROJECT_ROOT/.build/mas-sandbox-probe"
PROBE_APP="$PROBE_DIR/EyeOhSandboxProbe.app"
PROBE="$PROBE_APP/Contents/MacOS/EyeOhSandboxProbe"

rm -rf "$PROBE_APP"
mkdir -p "$PROBE_APP/Contents/MacOS"

swiftc \
    "$PROJECT_ROOT/Sources/EyeOh/AudioDevice.swift" \
    "$PROJECT_ROOT/Sources/EyeOh/AudioDeviceControlling.swift" \
    "$PROJECT_ROOT/Sources/EyeOh/CoreAudioClient.swift" \
    "$PROJECT_ROOT/Tools/AudioSandboxProbe.swift" \
    -o "$PROBE"

cat > "$PROBE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>au.com.darkice.eyeoh.sandbox-probe</string>
    <key>CFBundleName</key><string>EyeOhSandboxProbe</string>
    <key>CFBundleExecutable</key><string>EyeOhSandboxProbe</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Bluetooth access lets EyeOh reconnect paired audio devices you choose from its menu. EyeOh never pairs new devices automatically.</string>
</dict>
</plist>
PLIST

codesign \
    --force \
    --sign - \
    --entitlements "$PROJECT_ROOT/Config/EyeOh-MAS.entitlements" \
    "$PROBE_APP"

EYEOH_PROBE_WRITES="${EYEOH_PROBE_WRITES:-}" \
EYEOH_PROBE_BLUETOOTH_READ="${EYEOH_PROBE_BLUETOOTH_READ:-}" \
"$PROBE"
