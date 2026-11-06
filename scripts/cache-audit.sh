#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cache-audit.sh - check that development bloat is going into .dev-cache/
# and not into the usual C: locations.
#
# Usage:   bash scripts/cache-audit.sh
#
# Read-only: it only measures directories.
# ---------------------------------------------------------------------------
set -uo pipefail

_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVCACHE="$_root/.dev-cache"
LOCALAPPDATA="${LOCALAPPDATA:-$HOME/AppData/Local}"
APPDATA="${APPDATA:-$HOME/AppData/Roaming}"
USERPROFILE_WIN="${USERPROFILE:-$HOME}"

size_of() { # -> human size, "-" when absent
  [ -e "$1" ] || { printf '%s' '-'; return; }
  du -sh "$1" 2>/dev/null | cut -f1
}

echo "project: $_root"
echo
echo "=== inside the project (this is where it should go) ==============="
printf '%-28s %8s\n' '.dev-cache total' "$(size_of "$DEVCACHE")"
if [ -d "$DEVCACHE" ]; then
  for d in "$DEVCACHE"/*/; do
    [ -d "$d" ] || continue
    s="$(size_of "$d")"
    [ "$s" = "0" ] && continue
    printf '  %-26s %8s\n' "$(basename "$d")" "$s"
  done
fi

echo
echo "=== usual C: cache locations (watch these for growth) ============="
printf '%-28s %8s  %s\n' 'location' 'size' 'path'
check() { printf '%-28s %8s  %s\n' "$1" "$(size_of "$2")" "$2"; }
check 'npm cache'            "$LOCALAPPDATA/npm-cache"
check 'node-gyp headers'     "$LOCALAPPDATA/node-gyp"
check 'corepack'             "$LOCALAPPDATA/node/corepack"
check 'pnpm store'           "$LOCALAPPDATA/pnpm"
check 'yarn cache'           "$LOCALAPPDATA/Yarn"
check 'playwright browsers'  "$LOCALAPPDATA/ms-playwright"
check 'puppeteer cache'      "$HOME/.cache/puppeteer"
check 'electron cache'       "$LOCALAPPDATA/electron/Cache"
check 'cypress cache'        "$LOCALAPPDATA/Cypress/Cache"
check 'pip cache'            "$LOCALAPPDATA/pip/Cache"
check 'uv cache'             "$LOCALAPPDATA/uv"
check 'go build cache'       "$LOCALAPPDATA/go-build"
check 'go module cache'      "$USERPROFILE_WIN/go/pkg/mod"
check 'nuget packages'       "$USERPROFILE_WIN/.nuget/packages"
check 'nuget http cache'     "$LOCALAPPDATA/NuGet/v3-cache"
check 'cargo home'           "$USERPROFILE_WIN/.cargo"
check 'gradle home'          "$USERPROFILE_WIN/.gradle"
check 'maven repo'           "$USERPROFILE_WIN/.m2/repository"
check 'user site-packages'   "$APPDATA/Python"
check 'system temp'          "$LOCALAPPDATA/Temp"

echo
echo "=== temp used by this project ====================================="
printf '%-28s %8s  %s\n' 'TEMP inside project' "$(size_of "$DEVCACHE/tmp")" "$DEVCACHE/tmp"

echo
cat <<'NOTE'
Note: the C: rows may already hold data from other projects. What matters
for this project is that they do NOT grow while you work here. Compare a
before/after run of this script around an install or build.

Cleanup (never deletes anything outside this project):
  rm -rf .dev-cache/*        # nuclear: drops all local caches
  rm -rf .dev-cache/tmp/*    # just the scratch space
NOTE
