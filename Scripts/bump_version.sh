#!/usr/bin/env bash
# Usage: bump_version.sh VERSION [BUILD]
# Updates version.env, the website version string, Website/package.json and its
# lockfile, and rolls the CHANGELOG "Unreleased" section into a dated release.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $(basename "$0") VERSION [BUILD]" >&2
    exit 2
fi

NEW_VERSION=$1
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must look like 1.2.3, got: $NEW_VERSION" >&2
    exit 2
fi

# shellcheck disable=SC1091
source "$PROJECT_ROOT/version.env"

if [[ $# -eq 2 ]]; then
    NEW_BUILD=$2
else
    NEW_BUILD=$((BUILD_NUMBER + 1))
fi
if [[ ! "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
    echo "BUILD must be a whole number, got: $NEW_BUILD" >&2
    exit 2
fi

CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
INDEX_PAGE="$PROJECT_ROOT/Website/src/pages/index.astro"
RELEASE_DATE=$(date +%Y-%m-%d)

if /usr/bin/grep -Eq "^## $NEW_VERSION( |$)" "$CHANGELOG"; then
    echo "CHANGELOG already has a section for $NEW_VERSION." >&2
    exit 1
fi
if ! /usr/bin/grep -q '^## Unreleased$' "$CHANGELOG"; then
    echo "CHANGELOG has no '## Unreleased' section." >&2
    exit 1
fi
UNRELEASED_BODY=$(awk '/^## Unreleased$/{f=1; next} /^## /{f=0} f' "$CHANGELOG" | tr -d '[:space:]')
if [[ -z "$UNRELEASED_BODY" ]]; then
    echo "The Unreleased section is empty. Add release notes before bumping." >&2
    exit 1
fi
if ! /usr/bin/grep -Eq 'Version [0-9]+\.[0-9]+\.[0-9]+' "$INDEX_PAGE"; then
    echo "Could not find the 'Version x.y.z' string in $INDEX_PAGE." >&2
    exit 1
fi

cat > "$PROJECT_ROOT/version.env" <<ENV
MARKETING_VERSION=$NEW_VERSION
BUILD_NUMBER=$NEW_BUILD
ENV

NEW_VERSION="$NEW_VERSION" perl -pi -e 's/Version \d+\.\d+\.\d+/Version $ENV{NEW_VERSION}/' "$INDEX_PAGE"

NEW_VERSION="$NEW_VERSION" RELEASE_DATE="$RELEASE_DATE" \
    perl -pi -e 's/^## Unreleased$/## Unreleased\n\n## $ENV{NEW_VERSION} - $ENV{RELEASE_DATE}/' "$CHANGELOG"

NEW_VERSION="$NEW_VERSION" node -e '
const fs = require("fs");
const root = process.argv[1] + "/Website/";
for (const name of ["package.json", "package-lock.json"]) {
  const file = root + name;
  if (!fs.existsSync(file)) continue;
  const json = JSON.parse(fs.readFileSync(file, "utf8"));
  json.version = process.env.NEW_VERSION;
  if (json.packages && json.packages[""]) json.packages[""].version = process.env.NEW_VERSION;
  fs.writeFileSync(file, JSON.stringify(json, null, 2) + "\n");
}
' "$PROJECT_ROOT"

echo "Bumped to $NEW_VERSION (build $NEW_BUILD), dated $RELEASE_DATE."
"$PROJECT_ROOT/Scripts/check_release_metadata.sh"
