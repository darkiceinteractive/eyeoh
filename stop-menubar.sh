#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROCESS_PATTERN="$PROJECT_ROOT/build/EyeOh.app/Contents/MacOS/EyeOh"

if pkill -f "$PROCESS_PATTERN" 2>/dev/null; then
    echo "EyeOh stopped."
else
    echo "EyeOh was not running."
fi
