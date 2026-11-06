#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run.sh - run any dev command with project-local caches already loaded.
#
# Usage:   bash scripts/run.sh npm install
#          bash scripts/run.sh python -m pytest
#
# This is the wrapper agents and humans should use so a command can never
# start in a shell where the cache variables were not set.
# ---------------------------------------------------------------------------
set -euo pipefail

_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$_root/scripts/dev-env.sh"
cd "$_root"

if [ "$#" -eq 0 ]; then
  echo "usage: bash scripts/run.sh <command> [args...]" >&2
  exit 64
fi

exec "$@"
