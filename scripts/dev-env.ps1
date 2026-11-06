# ---------------------------------------------------------------------------
# dev-env.ps1 - project-local cache redirection (Windows PowerShell 5.1+)
#
# Usage:   . .\scripts\dev-env.ps1
#
# Every variable below points a tool's cache/temp/home at .dev-cache\ inside
# this project instead of the default C:\Users\<you>\AppData\... location.
# Keep this file and scripts/dev-env.sh in sync.
# ---------------------------------------------------------------------------

$DevCacheRoot = Split-Path -Parent $PSScriptRoot
if (-not $DevCacheRoot) { $DevCacheRoot = (Get-Location).Path }
$DevCache = Join-Path $DevCacheRoot '.dev-cache'

$dirs = @(
    'npm', 'node-gyp', 'corepack',
    'pnpm-store', 'pnpm-home', 'yarn\cache', 'yarn\global', 'bun',
    'ms-playwright', 'puppeteer', 'electron', 'electron-builder', 'cypress',
    'nx', 'turbo',
    'pip', 'uv', 'poetry', 'pdm', 'pycache', 'python-userbase',
    'go', 'go\bin', 'go-build', 'go-mod', 'go-tmp',
    'cargo', 'cargo-target', 'rustup', 'sccache',
    'gradle', 'maven',
    'nuget\packages', 'nuget\http-cache', 'nuget\scratch', 'dotnet-home',
    'xdg\cache', 'xdg\data', 'xdg\config', 'xdg\state',
    'tmp'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path (Join-Path $DevCache $d) | Out-Null }

# Node / JS -----------------------------------------------------------------
$env:NPM_CONFIG_CACHE        = Join-Path $DevCache 'npm'            # default %LOCALAPPDATA%\npm-cache
# node-gyp headers and the pnpm store are set in .npmrc (devdir / store-dir),
# which applies even when a shell was not prepared with this script.
$env:PNPM_HOME               = Join-Path $DevCache 'pnpm-home'
$env:COREPACK_HOME           = Join-Path $DevCache 'corepack'
$env:YARN_CACHE_FOLDER       = Join-Path $DevCache 'yarn\cache'
$env:YARN_GLOBAL_FOLDER      = Join-Path $DevCache 'yarn\global'
$env:YARN_ENABLE_GLOBAL_CACHE = 'false'
$env:BUN_INSTALL_CACHE_DIR   = Join-Path $DevCache 'bun'
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $DevCache 'ms-playwright'
$env:PUPPETEER_CACHE_DIR     = Join-Path $DevCache 'puppeteer'
$env:ELECTRON_CACHE          = Join-Path $DevCache 'electron'
$env:ELECTRON_BUILDER_CACHE  = Join-Path $DevCache 'electron-builder'
$env:CYPRESS_CACHE_FOLDER    = Join-Path $DevCache 'cypress'
$env:NX_CACHE_DIRECTORY      = Join-Path $DevCache 'nx'
$env:TURBO_CACHE_DIR         = Join-Path $DevCache 'turbo'

$env:NPM_CONFIG_AUDIT            = 'false'
$env:NPM_CONFIG_FUND             = 'false'
$env:NPM_CONFIG_UPDATE_NOTIFIER  = 'false'

# Python --------------------------------------------------------------------
$env:PIP_CACHE_DIR        = Join-Path $DevCache 'pip'
$env:PYTHONPYCACHEPREFIX  = Join-Path $DevCache 'pycache'
$env:PYTHONUSERBASE       = Join-Path $DevCache 'python-userbase'
$env:UV_CACHE_DIR         = Join-Path $DevCache 'uv'
$env:POETRY_CACHE_DIR     = Join-Path $DevCache 'poetry'
$env:PDM_CACHE_DIR        = Join-Path $DevCache 'pdm'

# Go ------------------------------------------------------------------------
$env:GOPATH     = Join-Path $DevCache 'go'
$env:GOCACHE    = Join-Path $DevCache 'go-build'
$env:GOMODCACHE = Join-Path $DevCache 'go-mod'
$env:GOBIN      = Join-Path $DevCache 'go\bin'
$env:GOTMPDIR   = Join-Path $DevCache 'go-tmp'

# .NET ----------------------------------------------------------------------
$env:NUGET_PACKAGES        = Join-Path $DevCache 'nuget\packages'
$env:NUGET_HTTP_CACHE_PATH = Join-Path $DevCache 'nuget\http-cache'
$env:NUGET_SCRATCH         = Join-Path $DevCache 'nuget\scratch'
$env:DOTNET_CLI_HOME       = Join-Path $DevCache 'dotnet-home'
$env:DOTNET_NOLOGO         = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# Rust (if/when added) ------------------------------------------------------
$env:CARGO_HOME        = Join-Path $DevCache 'cargo'
$env:RUSTUP_HOME       = Join-Path $DevCache 'rustup'
$env:CARGO_TARGET_DIR  = Join-Path $DevCache 'cargo-target'
$env:SCCACHE_DIR       = Join-Path $DevCache 'sccache'

# JVM (if/when added) -------------------------------------------------------
$env:GRADLE_USER_HOME = Join-Path $DevCache 'gradle'
$env:MAVEN_ARGS       = '-Dmaven.repo.local=' + (Join-Path $DevCache 'maven')   # needs Maven >= 3.9

# XDG-aware CLIs ------------------------------------------------------------
$env:XDG_CACHE_HOME  = Join-Path $DevCache 'xdg\cache'
$env:XDG_DATA_HOME   = Join-Path $DevCache 'xdg\data'
$env:XDG_CONFIG_HOME = Join-Path $DevCache 'xdg\config'
$env:XDG_STATE_HOME  = Join-Path $DevCache 'xdg\state'

# Generic temp --------------------------------------------------------------
$tmp = Join-Path $DevCache 'tmp'
$env:TMPDIR = $tmp
$env:TMP    = $tmp
$env:TEMP   = $tmp

$env:DEVCACHE = $DevCache
Write-Host "[dev-env] caches -> $DevCache"
