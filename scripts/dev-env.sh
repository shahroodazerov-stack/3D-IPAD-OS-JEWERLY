#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# dev-env.sh — project-local cache redirection (bash / Git Bash on Windows)
#
# Usage:   source scripts/dev-env.sh
#
# Every variable below points a tool's cache/temp/home at .dev-cache/ inside
# this project instead of the default C:\Users\<you>\AppData\... location.
# Keep this file and scripts/dev-env.ps1 in sync.
#
# This file is SOURCED, not executed: no `set -e`, no `exit`.
# ---------------------------------------------------------------------------

_devcache_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
DEVCACHE="$_devcache_root/.dev-cache"

# Windows tools (node, python, dotnet, go) want Windows-style paths.
_devcache_win() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# Layout ---------------------------------------------------------------------
mkdir -p \
  "$DEVCACHE"/npm "$DEVCACHE"/node-gyp "$DEVCACHE"/corepack \
  "$DEVCACHE"/pnpm-store "$DEVCACHE"/pnpm-home "$DEVCACHE"/yarn "$DEVCACHE"/bun \
  "$DEVCACHE"/ms-playwright "$DEVCACHE"/puppeteer "$DEVCACHE"/electron \
  "$DEVCACHE"/electron-builder "$DEVCACHE"/cypress "$DEVCACHE"/nx "$DEVCACHE"/turbo \
  "$DEVCACHE"/pip "$DEVCACHE"/uv "$DEVCACHE"/poetry "$DEVCACHE"/pdm \
  "$DEVCACHE"/pycache "$DEVCACHE"/python-userbase \
  "$DEVCACHE"/go "$DEVCACHE"/go-build "$DEVCACHE"/go-mod "$DEVCACHE"/go-tmp \
  "$DEVCACHE"/cargo "$DEVCACHE"/cargo-target "$DEVCACHE"/rustup "$DEVCACHE"/sccache \
  "$DEVCACHE"/gradle "$DEVCACHE"/maven \
  "$DEVCACHE"/nuget/packages "$DEVCACHE"/nuget/http-cache "$DEVCACHE"/nuget/scratch \
  "$DEVCACHE"/dotnet-home \
  "$DEVCACHE"/xdg/cache "$DEVCACHE"/xdg/data "$DEVCACHE"/xdg/config "$DEVCACHE"/xdg/state \
  "$DEVCACHE"/tmp

# Node / JS ------------------------------------------------------------------
export NPM_CONFIG_CACHE="$(_devcache_win "$DEVCACHE/npm")"          # default %LOCALAPPDATA%\npm-cache
# node-gyp headers and the pnpm store are set in .npmrc (devdir / store-dir),
# which applies even when a shell was not prepared with this script.
export PNPM_HOME="$(_devcache_win "$DEVCACHE/pnpm-home")"
export COREPACK_HOME="$(_devcache_win "$DEVCACHE/corepack")"
export YARN_CACHE_FOLDER="$(_devcache_win "$DEVCACHE/yarn/cache")"
export YARN_GLOBAL_FOLDER="$(_devcache_win "$DEVCACHE/yarn/global")"
export YARN_ENABLE_GLOBAL_CACHE=false
export BUN_INSTALL_CACHE_DIR="$(_devcache_win "$DEVCACHE/bun")"
export PLAYWRIGHT_BROWSERS_PATH="$(_devcache_win "$DEVCACHE/ms-playwright")"
export PUPPETEER_CACHE_DIR="$(_devcache_win "$DEVCACHE/puppeteer")"
export ELECTRON_CACHE="$(_devcache_win "$DEVCACHE/electron")"
export ELECTRON_BUILDER_CACHE="$(_devcache_win "$DEVCACHE/electron-builder")"
export CYPRESS_CACHE_FOLDER="$(_devcache_win "$DEVCACHE/cypress")"
export NX_CACHE_DIRECTORY="$(_devcache_win "$DEVCACHE/nx")"
export TURBO_CACHE_DIR="$(_devcache_win "$DEVCACHE/turbo")"

# Less network churn (nothing is stored outside .dev-cache either way).
export NPM_CONFIG_AUDIT=false
export NPM_CONFIG_FUND=false
export NPM_CONFIG_UPDATE_NOTIFIER=false

# Python --------------------------------------------------------------------
export PIP_CACHE_DIR="$(_devcache_win "$DEVCACHE/pip")"            # default %LOCALAPPDATA%\pip\Cache
export PYTHONPYCACHEPREFIX="$(_devcache_win "$DEVCACHE/pycache")"  # keeps __pycache__ out of the tree
export PYTHONUSERBASE="$(_devcache_win "$DEVCACHE/python-userbase")" # pip --user, default %APPDATA%\Python
export UV_CACHE_DIR="$(_devcache_win "$DEVCACHE/uv")"
export POETRY_CACHE_DIR="$(_devcache_win "$DEVCACHE/poetry")"
export PDM_CACHE_DIR="$(_devcache_win "$DEVCACHE/pdm")"

# Go ------------------------------------------------------------------------
export GOPATH="$(_devcache_win "$DEVCACHE/go")"
export GOCACHE="$(_devcache_win "$DEVCACHE/go-build")"            # default %LOCALAPPDATA%\go-build
export GOMODCACHE="$(_devcache_win "$DEVCACHE/go-mod")"
export GOBIN="$(_devcache_win "$DEVCACHE/go/bin")"
export GOTMPDIR="$(_devcache_win "$DEVCACHE/go-tmp")"

# .NET ----------------------------------------------------------------------
export NUGET_PACKAGES="$(_devcache_win "$DEVCACHE/nuget/packages")"       # default %USERPROFILE%\.nuget\packages
export NUGET_HTTP_CACHE_PATH="$(_devcache_win "$DEVCACHE/nuget/http-cache")"
export NUGET_SCRATCH="$(_devcache_win "$DEVCACHE/nuget/scratch")"
export DOTNET_CLI_HOME="$(_devcache_win "$DEVCACHE/dotnet-home")"
export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Rust (if/when added) ------------------------------------------------------
export CARGO_HOME="$(_devcache_win "$DEVCACHE/cargo")"
export RUSTUP_HOME="$(_devcache_win "$DEVCACHE/rustup")"
export CARGO_TARGET_DIR="$(_devcache_win "$DEVCACHE/cargo-target")"
export SCCACHE_DIR="$(_devcache_win "$DEVCACHE/sccache")"

# JVM (if/when added) -------------------------------------------------------
export GRADLE_USER_HOME="$(_devcache_win "$DEVCACHE/gradle")"
export MAVEN_ARGS="-Dmaven.repo.local=$(_devcache_win "$DEVCACHE/maven")"  # needs Maven >= 3.9

# XDG-aware CLIs ------------------------------------------------------------
export XDG_CACHE_HOME="$(_devcache_win "$DEVCACHE/xdg/cache")"
export XDG_DATA_HOME="$(_devcache_win "$DEVCACHE/xdg/data")"
export XDG_CONFIG_HOME="$(_devcache_win "$DEVCACHE/xdg/config")"
export XDG_STATE_HOME="$(_devcache_win "$DEVCACHE/xdg/state")"

# Generic temp (build steps, unpackers, native compilers) -------------------
export TMPDIR="$DEVCACHE/tmp"
export TMP="$DEVCACHE/tmp"
export TEMP="$DEVCACHE/tmp"

export DEVCACHE
unset _devcache_root
unset -f _devcache_win
