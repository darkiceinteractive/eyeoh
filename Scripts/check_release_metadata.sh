#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# version.env is resolved from the repository root at runtime.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

if ! grep -Fq "Version $MARKETING_VERSION" "$PROJECT_ROOT/Website/index.html"; then
    echo "Website version does not match MARKETING_VERSION=$MARKETING_VERSION." >&2
    exit 1
fi

if ! grep -Fq "## $MARKETING_VERSION" "$PROJECT_ROOT/CHANGELOG.md"; then
    echo "Changelog has no section for $MARKETING_VERSION." >&2
    exit 1
fi

echo "Release metadata matches version $MARKETING_VERSION."
