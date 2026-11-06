# F — Engineering and delivery on GitHub Actions

**Stream:** project layout, test strategy, CI runners, caching, cost, gates · **Researched:** 2026-11-06
**Labels:** FACT (cited) / INFERENCE (reasoning)

---

## 1. Repository and project layout

```
3D-IPAD-OS-JEWERLY/
├─ AGENTS.md                     # standing ground rules (cache discipline etc.)
├─ README.md                     # product overview
├─ .github/workflows/ios.yml     # build + unit tests + UI smoke (the gate)
├─ FacetForge.xcodeproj          # app target + AppTests + AppUITests
├─ Packages/
│  ├─ FFMath/                    # vectors, matrices, quaternions, tolerances
│  ├─ FFGeometry/                # curves, meshes, tessellation, BVH
│  ├─ FFSolids/                  # booleans, shell, fillet, validation
│  ├─ FFJewelry/                 # ring, heads, gems, settings, manufacturing rules
│  ├─ FFDocument/                # document model, file format, undo
│  ├─ FFRender/                  # RealityKit/Metal viewport + materials
│  └─ FFUI/                      # design system, screens, panels
├─ docs/                         # research + MASTER-PLAN + ADRs
└─ .dev-cache/                   # every local cache (gitignored, per AGENTS.md)
```

- **FACT:** Apple recommends local Swift packages for feature code, added to the app target's
  Frameworks/Libraries/Embedded Content. [1]
- **FACT:** Apple recommends a test pyramid: many fast unit tests, fewer integration tests, a thin
  UI-test layer. Xcode 16+ ships Swift Testing; XCTest/XCUIAutomation remain for UI. [2]
- **INFERENCE:** commit `Package.resolved` and shared schemes (`xcshareddata/xcschemes`); never
  commit `xcuserdata`. One shared test plan so a single `xcodebuild test` covers packages + app.

## 2. Commands that define the gate

```bash
xcodebuild build \
  -project FacetForge.xcodeproj -scheme FacetForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' \
  -derivedDataPath .build/DerivedData \
  -packageCachePath .build/PackageCache \
  -resultBundlePath .build/Results/Build.xcresult \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

xcodebuild test-without-building \
  -project FacetForge.xcodeproj -scheme FacetForge \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.5' \
  -derivedDataPath .build/DerivedData \
  -resultBundlePath .build/Results/Test.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 300 \
  -retry-tests-on-failure -test-iterations 2

xcrun simctl bootstatus "iPad Pro 11-inch (M5)" -b
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/FacetForge.app
xcrun simctl launch booted com.shahroodazerov.facetforge
xcrun simctl io booted screenshot .build/Results/smoke.png
```

- **FACT:** simulator builds need no signing; `CODE_SIGNING_ALLOWED=NO` is the standard recipe. [3][4]
- **FACT:** `simctl bootstatus -b`, `install`, `launch`, `io … screenshot` exist. [5]
- **FACT:** `-test-iterations` + `-retry-tests-on-failure` is Apple's flaky-test recipe. [6]
- **INFERENCE:** pass `-derivedDataPath` and `-packageCachePath` **always** — otherwise Xcode writes
  multi-GB caches into `~/Library/Developer/Xcode/DerivedData` and
  `~/Library/Caches/org.swift.swiftpm`, which AGENTS.md forbids.

## 3. Runner selection (as of Nov 2026)

| Runner | Arch | Xcode | Notes | Label |
| --- | --- | --- | --- | --- |
| `macos-26` (default `macos-latest`) | arm64, 3-core M1, 7 GB | Xcode 26.6 default, 26.0.1–26.6 present | Includes iPad Pro 11/13-inch (M5), iPad Air, iPad mini sims on iOS 26.2/26.4/26.5 | FACT [7][8] |
| `macos-15` | arm64 | Xcode 16.x | still available | FACT [7] |
| `macos-26-intel` / `-large` | x86_64, 4-core, 14 GB | Xcode 26.x | static UDIDs; only use if arm64 is unavailable | FACT [7] |
| `macos-14` | arm64 | — | **retired 2 Nov 2026** | FACT [9] |

- **FACT:** arm64 runners have no static simulator UDID; Intel ones do — so name-based
  destinations are the portable choice. [10]
- **INFERENCE:** pin `macos-26` and `xcode-select -s /Applications/Xcode_26.6.app`; never use
  `macos-latest` for reproducibility.

## 4. Caching (and why most Xcode caches do not help)

- **FACT:** cache `SourcePackages` keyed on `hashFiles('Package.resolved')` — cheap and effective.
- **FACT:** caching `DerivedData`/`.build` alone usually rebuilds everything, because
  `actions/checkout` resets mtimes and `actions/cache` extraction changes inodes, which llbuild
  treats as modification; real incremental builds need `fetch-depth: 0`, mtime restore and
  `IgnoreFileSystemDeviceInodeChanges=YES` with a `github.sha`-keyed cache. [11]
- **FACT:** repository cache limit 10 GB; unused entries evicted after 7 days. [12]
- **INFERENCE:** for a 10-minute iOS job, caching SourcePackages only is the right cost/benefit;
  skip DerivedData caching until build time dominates.

## 5. Artifacts, timeouts, flakiness

- **FACT:** upload `.xcresult` with `if: always()`; `actions/upload-artifact@v4` artifacts are
  immutable; retention configurable (1–400 days private, default 90). [13]
- **FACT:** job `timeout-minutes` defaults to 360. [14]
- **INFERENCE:** job 45 min, build step 20 min, test step 25 min, `-destination-timeout 120`.
- **FACT:** runner image regressions break suites regularly (2× slowdowns Jan 2025, simulators
  failing to start Aug 2025, Xcode 26 test hangs Nov 2025). [15][16][17]
- **INFERENCE:** pin image + Xcode, retry once at job level, quarantine a flaky test instead of
  adding global retries.

## 6. Cost

- **FACT:** macOS standard runner **$0.062/min**; 12-core Intel `macos_l` $0.077; 5-core M2 Pro
  `macos_xl` $0.102. Private-repo usage draws from dollar credit ($12 Free, $18 Pro/Team,
  $300 Enterprise), not fixed minutes. [18][19]
- **INFERENCE:** ~10 billed minutes per gate ≈ **$0.62 per phase**; 200 phases ≈ $125 of macOS
  time, plus reruns. Public repos are free — decide visibility deliberately (the mission repo is
  currently public).

## 7. The gate (Phase 1 definition)

A phase is **green** only when all of these pass on `macos-26`:

1. `xcodebuild build` for the iPad simulator with signing disabled.
2. `xcodebuild test` for all unit suites (Swift Testing) + the current phase's acceptance tests.
3. UI smoke: app installs, launches, and the phase's screen renders (screenshot artifact).
4. No warnings promoted to errors are introduced; no new `TODO`/`fatalError` in shipping paths.
5. `.xcresult` + screenshot uploaded; job under 45 minutes.

Any red gate blocks the next phase. Flaky tests are fixed or quarantined with an issue, never
silently retried forever.

## 8. Local cache discipline for Xcode (AGENTS.md compliance)

| Item | Default (forbidden) | Local setting |
| --- | --- | --- |
| DerivedData | `~/Library/Developer/Xcode/DerivedData` | `-derivedDataPath .build/DerivedData` + workspace setting `DerivedDataLocationStyle=WorkspaceRelativePath` |
| SPM package cache | `~/Library/Caches/org.swift.swiftpm` | `-packageCachePath .build/PackageCache` |
| SPM checkouts | DerivedData/SourcePackages | follows DerivedData |
| Module cache | inside DerivedData | follows DerivedData |
| Simulator devices/runtimes | `~/Library/Developer/CoreSimulator` | **Apple-managed, not relocatable** → known exception; keep device count minimal, `simctl delete unavailable` |
| Xcode archives / DeviceSupport | `~/Library/Developer/Xcode` | managed by Xcode; archives only on release, deleted after upload |
| Swift Package Manager CLI | `~/.swiftpm` | `--cache-path`/`--scratch-path` flags in scripts |

INFERENCE: phases 1–2 must extend `scripts/dev-env.sh`/`.ps1` with `CLANG_MODULE_CACHE_PATH`,
`SWIFT_MODULE_CACHE_PATH`, `XDG_CACHE_HOME` already set, and document the CoreSimulator exception
in `AGENTS.md`.

## 9. Local git state (prepared this pass)

- `git init -b main`, `origin` = `https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY.git`.
- `git fetch --depth=1 origin main`; remote `main` contains only `README.md` (1 file, commit `1a8d68b`).
- Local `main` tracks `origin/main`; AGENTS.md, scripts, `.gitignore`, `.npmrc`, `docs/` remain
  **untracked and uncommitted**. Nothing pushed. `gh` is not authenticated on this machine.
- Next implementation step (phase 1) commits on a `phase-01-foundation` branch and pushes only
  when the user asks; CI cannot be green until the workflow exists.

## 10. Open questions

- Repo visibility/cost model was not confirmed with the owner — public is free, private draws credit.
- Whether the account can add Actions secrets for signing later (TestFlight needs certificates).
- Simulator device name for iPad Pro 11-inch (M5) must be re-checked per Xcode image at runtime
  (`xcrun simctl list devicetypes`), not hard-coded blindly.

## Sources

[1] https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages
[2] https://developer.apple.com/documentation/xcode/testing
[3] https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds
[4] https://docs.bitrise.io/en/bitrise-ci/testing/testing-ios-apps/building-an-ios-app-for-a-simulator
[5] https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference
[6] https://developer.apple.com/videos/play/wwdc2021/10296/
[7] https://github.com/actions/runner-images
[8] https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md
[9] https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement
[10] https://docs.github.com/en/actions/reference/runners/github-hosted-runners
[11] https://aleos.dev/posts/2026-02-17-xcode-ci-build-caching/
[12] https://docs.github.com/en/billing/concepts/product-billing/github-actions
[13] https://docs.github.com/en/actions/tutorials/store-and-share-data
[14] https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
[15] https://github.com/actions/runner-images/issues/11509
[16] https://github.com/actions/runner-images/issues/12777
[17] https://github.com/actions/runner-images/issues/13264
[18] https://docs.github.com/en/billing/reference/actions-runner-pricing
[19] https://docs.github.com/en/billing/concepts/product-billing/github-actions
