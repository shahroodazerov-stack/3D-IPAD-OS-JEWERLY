# AGENTS.md — Ground rules for this project

Read this before doing anything in this repo. These rules are binding for agents
and humans alike, on every feature, fix and experiment.

## Project status

Empty scaffold. Stack not chosen yet. When the stack is chosen, update
**"Project facts"** at the bottom and add any stack-specific rules there.

---

## Rule 1 (non-negotiable): all dev cache and bloat stays in this folder

Nothing produced by developing this project may be written to the default
`C:\Users\shahr\AppData\...`, `C:\Users\shahr\.npm`, `C:\Users\shahr\go`,
`C:\Users\shahr\.nuget`, or system-temp locations. Every cache, download,
store, temp file and build scratch dir that a tool supports redirecting goes
into **`.dev-cache/`** at the project root.

Why: this folder is the single place to look at, measure, move or delete. No
hunting through `AppData` and no growth on C: from this project.

`.dev-cache/` is gitignored. It is disposable — deleting it must never lose
anything you cannot regenerate with an install or build.

### How to run any command

Never run install/build/test/dev commands from a bare shell. Use one of:

```bash
# bash / Git Bash (what agents use here)
source scripts/dev-env.sh
npm install

# or, preferred: one-shot wrapper
bash scripts/run.sh npm install
bash scripts/run.sh python -m pytest
```

```powershell
# Windows PowerShell
. .\scripts\dev-env.ps1
npm install
```

`.npmrc` in the repo root pins the npm-side paths (`cache`, `devdir` for
node-gyp headers, `store-dir` for pnpm), so even a bare `npm install` in a
fresh shell stays local. The env scripts cover everything else.

npm may print `Unknown project config "devdir"` / `"store-dir"` warnings.
That is expected: npm itself does not read those keys, but forwards them to
node-gyp and pnpm, which do. Do not delete them to silence the warning.

`scripts/run.sh` sources the env file and `exec`s your command, so caches are
correct even in a fresh shell.

### Layout

```
.dev-cache/
  npm/ node-gyp/ corepack/                    node & npm
  pnpm-store/ pnpm-home/ yarn/ bun/           other package managers
  ms-playwright/ puppeteer/ electron/          browser & app binaries
  electron-builder/ cypress/ nx/ turbo/        build tooling
  pip/ uv/ poetry/ pdm/ pycache/ python-userbase/   python
  go/ go-build/ go-mod/ go-tmp/               go
  nuget/packages|http-cache|scratch/ dotnet-home/   .NET
  cargo/ cargo-target/ rustup/ sccache/       rust
  gradle/ maven/                              JVM
  xdg/cache|data|config|state/                XDG-aware CLIs
  tmp/                                        TEMP/TMP/TMPDIR for all commands
```

### What is already redirected

Paths are project-relative under `.dev-cache/`. `dev-env.sh` and `dev-env.ps1`
set every row that names an env var; the rows that name `.npmrc` are set
there so they apply even in an unprepared shell. Keep the three files in sync.

| Tool | Env var | Location | Default it replaces |
| --- | --- | --- | --- |
| npm / npx | `NPM_CONFIG_CACHE`, `.npmrc` `cache` | `npm/` | `%LOCALAPPDATA%\npm-cache` |
| npm temp files | follows `TEMP` (last row) | `tmp/` | `%TEMP%` |
| node-gyp headers | `.npmrc` `devdir` | `node-gyp/` | `%LOCALAPPDATA%\node-gyp` |
| pnpm | `.npmrc` `store-dir`, `PNPM_HOME` | `pnpm-store/`, `pnpm-home/` | `%LOCALAPPDATA%\pnpm` |
| corepack | `COREPACK_HOME` | `corepack/` | `%LOCALAPPDATA%\node\corepack` |
| yarn | `YARN_CACHE_FOLDER`, `YARN_GLOBAL_FOLDER`, `YARN_ENABLE_GLOBAL_CACHE=false` | `yarn/` | `%LOCALAPPDATA%\Yarn` |
| bun | `BUN_INSTALL_CACHE_DIR` | `bun/` | `%LOCALAPPDATA%\bun` |
| Playwright | `PLAYWRIGHT_BROWSERS_PATH` | `ms-playwright/` | `%LOCALAPPDATA%\ms-playwright` |
| Puppeteer | `PUPPETEER_CACHE_DIR` | `puppeteer/` | `~\.cache\puppeteer` |
| Electron | `ELECTRON_CACHE` | `electron/` | `%LOCALAPPDATA%\electron\Cache` |
| electron-builder | `ELECTRON_BUILDER_CACHE` | `electron-builder/` | `%LOCALAPPDATA%\electron-builder\Cache` |
| Cypress | `CYPRESS_CACHE_FOLDER` | `cypress/` | `%LOCALAPPDATA%\Cypress\Cache` |
| Nx | `NX_CACHE_DIRECTORY` | `nx/` | `.nx\cache`, `%LOCALAPPDATA%` |
| Turborepo | `TURBO_CACHE_DIR` | `turbo/` | `%LOCALAPPDATA%\turborepo` |
| pip | `PIP_CACHE_DIR` | `pip/` | `%LOCALAPPDATA%\pip\Cache` |
| Python bytecode | `PYTHONPYCACHEPREFIX` | `pycache/` | `__pycache__` next to sources |
| pip `--user` installs | `PYTHONUSERBASE` | `python-userbase/` | `%APPDATA%\Python` |
| uv | `UV_CACHE_DIR` | `uv/` | `%LOCALAPPDATA%\uv\cache` |
| Poetry | `POETRY_CACHE_DIR` | `poetry/` | `%LOCALAPPDATA%\pypoetry\Cache` |
| PDM | `PDM_CACHE_DIR` | `pdm/` | `%LOCALAPPDATA%\pdm` |
| Go build | `GOCACHE` | `go-build/` | `%LOCALAPPDATA%\go-build` |
| Go modules | `GOMODCACHE`, `GOPATH` | `go-mod/`, `go/` | `%USERPROFILE%\go` |
| Go tool binaries | `GOBIN` | `go/bin/` | `%USERPROFILE%\go\bin` |
| Go temp | `GOTMPDIR` | `go-tmp/` | `%TEMP%` |
| NuGet packages | `NUGET_PACKAGES` | `nuget/packages/` | `%USERPROFILE%\.nuget\packages` |
| NuGet http / scratch | `NUGET_HTTP_CACHE_PATH`, `NUGET_SCRATCH` | `nuget/http-cache/`, `nuget/scratch/` | `%LOCALAPPDATA%\NuGet`, `%TEMP%` |
| dotnet CLI | `DOTNET_CLI_HOME` | `dotnet-home/` | `%USERPROFILE%` |
| Cargo | `CARGO_HOME` | `cargo/` | `%USERPROFILE%\.cargo` |
| Cargo target | `CARGO_TARGET_DIR` | `cargo-target/` | `./target` |
| Rustup | `RUSTUP_HOME` | `rustup/` | `%USERPROFILE%\.rustup` |
| sccache | `SCCACHE_DIR` | `sccache/` | `%LOCALAPPDATA%\Mozilla\sccache` |
| Gradle | `GRADLE_USER_HOME` | `gradle/` | `%USERPROFILE%\.gradle` |
| Maven | `MAVEN_ARGS=-Dmaven.repo.local=...` | `maven/` | `%USERPROFILE%\.m2\repository` |
| XDG-aware CLIs | `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME` | `xdg/*` | `%LOCALAPPDATA%`, `%APPDATA%` |
| everything else | `TEMP`, `TMP`, `TMPDIR` | `tmp/` | `%LOCALAPPDATA%\Temp` |

### Adding a new tool or dependency (required checklist)

1. Find the tool's cache directory setting. Search its docs for
   `CACHE`, `HOME`, `STORE`, `DIR` env vars — most popular tools have one.
2. Add the variable to **both** `scripts/dev-env.sh` and `scripts/dev-env.ps1`,
   pointing at a new subdirectory of `.dev-cache/`.
3. Create the directory in the `mkdir -p` list / `$dirs` array in those files.
4. Add a row to the table above.
5. Verify with `bash scripts/cache-audit.sh` before and after an install: the
   C: rows must not grow.
6. If the tool has no cache setting, use `TEMP` redirection (already active)
   and note it under "Known exceptions".

### Verification

```bash
bash scripts/cache-audit.sh      # sizes: .dev-cache vs the usual C: locations
source scripts/dev-env.sh && npm config get cache   # must print ...\.dev-cache\npm
```

### Known exceptions (cannot be moved here)

Be honest about these instead of pretending the rule is absolute:

- **Docker Desktop** images/volumes live in the WSL2 VM disk
  (`%LOCALAPPDATA%\Docker\wsl`). Move it via Docker Desktop → Settings →
  Resources → Advanced, not via env var.
- **Global npm/pip installs** of unrelated tools (`npm i -g`) are per-user,
  not per-project. Install project tooling as devDependencies or into
  `.dev-cache/` instead of globally.
- **Native SDK installers** (Visual Studio Build Tools, CUDA, Windows SDK)
  install system-wide; there is no cache redirect.
- **Windows/Defender/GPU caches** (shader caches, prefetch, indexing) are
  OS-managed and out of scope.
- **Browser profiles** for automation: pass `--user-data-dir` /
  `--profile-directory` pointing into `.dev-cache/` when driving a real browser.
- **Some Rust/Java build caches** only exist because of `CARGO_TARGET_DIR` /
  `GRADLE_USER_HOME` above; if a plugin writes elsewhere, add it here.

If a tool ignores all of this and still writes to C:, document it under
"Known exceptions" with the reason, so nobody re-investigates it.

---

## Working agreements

- **Scope discipline.** Do what was asked, completely, and nothing adjacent.
  No drive-by refactors, renames, dependency swaps or "polish".
- **Verify before claiming done.** Run the smallest check that proves the
  change (typecheck, build, one focused test). Report what ran and what could
  not run. Never describe an unrun check as passing.
- **Fix causes, not symptoms.** No skipped tests, weakened assertions,
  swallowed errors, or lint/type suppressions to turn a check green.
- **Git.** Don't commit, push, branch or open PRs unless asked. When asked,
  stage only your own files, never `git add -A` over someone else's work.
  Commit messages: `type(scope): summary` (feat, fix, refactor, docs, test,
  chore), imperative, focused on *why*.
- **Dependencies.** Ask before adding a package or a third-party SaaS. Prefer
  the standard library and what the project already uses.
- **Secrets.** Never commit `.env`, keys or tokens; never print them in logs or
  chat. Use `.env.example` for the shape only.
- **No new top-level clutter.** New tooling goes in `scripts/`, generated
  output in `.dev-cache/`, docs in the repo root or `docs/`.
- **Path caveat.** This project path contains a space (`3D JEWERLY`). Quote
  paths in scripts and configs; if a tool breaks on spaces, note it here
  instead of silently renaming the folder.

## Project facts

- Runtime available: Node.js 24 / npm 11, Python 3.15, Go, .NET 8, Git.
- iOS stack: SwiftUI app target, iPadOS 26.0 deployment target, hand-authored
  `FacetForge.xcodeproj`; system frameworks only, no third-party packages.
- Test runner: XCUITest/XCTest planned; no test target exists in Phase 1.
- Not installed: pnpm, yarn, bun, cargo, rustup (env vars for them are set
  pre-emptively so they stay local the day they are added).
