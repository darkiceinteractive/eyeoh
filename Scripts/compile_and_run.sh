#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="EyeOh"
APP_BUNDLE="$PROJECT_ROOT/build/$APP_NAME.app"
PROCESS_PATTERN="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -f "$PROCESS_PATTERN" 2>/dev/null || true

if [[ "${1:-}" == "--test" ]]; then
    swift test --package-path "$PROJECT_ROOT"
fi

"$PROJECT_ROOT/Scripts/package_app.sh" release
open "$APP_BUNDLE"

for _ in {1..10}; do
    if pgrep -f "$PROCESS_PATTERN" >/dev/null 2>&1; then
        echo "EyeOh is running."
        exit 0
    fi
    sleep 0.4
done

echo "EyeOh exited during launch." >&2
exit 1
