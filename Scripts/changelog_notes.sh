#!/usr/bin/env bash
# Prints the CHANGELOG.md section body for VERSION (used for GitHub release notes).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=${1:-}
if [[ -z "$VERSION" ]]; then
    echo "Usage: $(basename "$0") VERSION" >&2
    exit 2
fi

NOTES=$(awk -v v="$VERSION" '
    /^## / { if (found) exit; if (index($0, "## " v) == 1) { found = 1; next } }
    found { print }
' "$PROJECT_ROOT/CHANGELOG.md")

if [[ -z "${NOTES//[[:space:]]/}" ]]; then
    echo "No CHANGELOG section found for $VERSION." >&2
    exit 1
fi
printf '%s\n' "$NOTES"
