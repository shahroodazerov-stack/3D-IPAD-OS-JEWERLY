# Phase progress

One row per phase. A phase is only `green` when the GitHub Actions gate passed. `done-local`
means the work is committed but CI has not run; `wip` means the branch is open and the run is
not green yet. Update this file in the same commit as the phase.

| Phase | Status | Date | Gate run | Notes |
| --- | --- | --- | --- | --- |
| 0 | green | 2026-11-06 | [42210748897](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42210748897) | Six dossiers, citation audit, repaired 200-phase plan, Phase 0 workflow/checkers, branding sheet. Gate green on branch `phase-0-gate`; not merged to `main` by design |
| 1 | green | 2026-11-06 | [42211739495](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42211739495) | Hand-authored `FacetForge.xcodeproj`, shared scheme, SwiftUI launch screen. Gate built `FacetForge.app`, installed and launched `com.shahroodazerov.facetforge`, and uploaded a 2064×2752 screenshot. App is a stub screen; viewport Phase 9, document Phase 12, tests Phase 2. Branch-green, not merged |
| 2 | green | 2026-11-06 | [42217712774](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42217712774) | Unit and UI test targets in the hand-authored project, shared scheme test action, `/Test.xcresult` and screenshot artifacts. Green run executed 4 unit tests and the launch UI smoke. The gate was then proven to fail on the throwaway `phase-2-gate-teeth` [run 42219539127](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42219539127) with a deliberately wrong assertion. The throwaway branch was kept at that red commit as evidence; the phase branch never carried the change. Branch-green, not merged |
| 3 | green | 2026-11-06 | [42223050145](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42223050145) | FFUI semantic palette, type/space/radius/elevation tokens, 12 primitives, component gallery, 19 text/background contrast pairs, 12 component image snapshots and gallery screenshots. Green run executed 10 unit tests (WCAG AA contrast and snapshot hashes) and 2 UI tests (gallery sections and launch smoke). Branch-green, not merged |
| 4 | green | 2026-11-06 | [42230744875](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42230744875) | Adaptive three-zone shell (tools, viewport, inspector), collapsible panels, width-driven breakpoints 640/820/1024/1366 pt, `UISceneSizeRestrictions` at 640×480 pt, five-width layout snapshot tests and a five-width XCUITest. Green run executed 15 unit tests and 4 UI tests, including the 640/700/820/1024/1366 width pass, collapse/restore, gallery and launch smoke. App code is unchanged after this run; the later test-only hardening commit (`43a1754`) adds window-containment assertions and screen-level captures but the macOS job in its three runs was cancelled with zero steps while acquiring a runner, documented below. Branch-green, not merged |
| 5 | pending | — | — | Math core |

Status vocabulary:

- `pending` — not started.
- `wip` — branch open, gate not yet green.
- `green` — GitHub Actions `ios.yml` green and artifacts uploaded. Phases 0–4 are
  branch-green by design; the plan requires review before `main` is merged.
- `blocked` — stopped with a written reason (never silent).

## Known deviations

- The repository remote `main` contains only `README.md` (commit `1a8d68b`). Phase 0 work is
  committed on a branch, not merged into `main` without review.
- Phase 0 is green on `phase-0-gate` (run 42210748897) and deliberately not merged to `main`
  without review, per the Phase 0 note in the plan.
- Phase 1 is green on `phase-1-app-target` (run 42211739495); the app was a branded
  launch-screen stub. The viewport begins in Phase 9, the document model in Phase 12, and tests
  in Phase 2. The Phase 1 gate proves build, install, launch and screenshot, not CAD behaviour.
- Phase 2's first green run was not taken as proof of the gate's teeth: assertion
  `AppIdentity.phase == 2` was deliberately changed to an impossible value on
  `phase-2-gate-teeth`. Run 42219539127 went red in the unit suite. The assertion was never
  changed on `phase-2-test-gate`; the throwaway branch remains at the red commit only as
  evidence and is not merged. That failing run is not a released state.
- Phase 4's shipping shell is still a behaviour shell, not CAD: the viewport draws a fixed ring
  preview and grid, the inspector edits a string field only, and no document, geometry or render
  kernel exists yet. The gate proves the layout at the five widths and that panels collapse, not
  that the ring is editable. Phase 5 starts the math core.
- The Phase 3 component snapshots are image digests of an `ImageRenderer` pass, not device
  screenshots; the gallery screenshots are the device-level evidence.
- The GitHub Actions `ios` job no longer skips the build: it validates the project with
  `xcodebuild -list`, builds for an iPad simulator, installs, launches and screenshots.
- GitHub's hosted macOS pool repeatedly cancelled the Phase 4 hardening runs
  [42232636599](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42232636599),
  [42237345115](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42237345115)
  and
  [42239748028](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42239748028)
  after 15 minutes queued, with no runner assigned and no steps executed; two reruns of
  42239748028 (15:22 and 15:41 UTC) were cancelled the same way. The run is recorded as
  `failure` because its macOS job was cancelled. The static job passed every time. The last
  green Phase 4 run therefore predates the test-only hardening commit; the app sources are
  identical, but `43a1754` has not been compiled by Xcode. Re-running `phase-4-adaptive-shell`
  when the macOS pool is healthy remains the only outstanding code check.
