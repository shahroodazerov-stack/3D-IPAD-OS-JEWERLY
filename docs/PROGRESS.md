# Phase progress

One row per phase. A phase is only `green` when the GitHub Actions gate passed. `done-local`
means the work is committed but CI has not run; `wip` means the branch is open and the run is
not green yet. Update this file in the same commit as the phase.

| Phase | Status | Date | Gate run | Notes |
| --- | --- | --- | --- | --- |
| 0 | green | 2026-11-06 | [42210748897](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42210748897) | Six dossiers, citation audit, repaired 200-phase plan, Phase 0 workflow/checkers, branding sheet. Gate green on `phase-0-gate`; fast-forwarded to `main` in the phase-4 consolidation |
| 1 | green | 2026-11-06 | [42211739495](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42211739495) | Hand-authored `FacetForge.xcodeproj`, shared scheme, SwiftUI launch screen. Gate built `FacetForge.app`, installed and launched `com.shahroodazerov.facetforge`, and uploaded a 2064×2752 screenshot. App is a stub screen; viewport Phase 9, document Phase 12, tests Phase 2. Now on `main` |
| 2 | green | 2026-11-06 | [42217712774](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42217712774) | Unit and UI test targets in the hand-authored project, shared scheme test action, `/Test.xcresult` and screenshot artifacts. Green run executed 4 unit tests and the launch UI smoke. The gate was then proven to fail on the throwaway `phase-2-gate-teeth` [run 42219539127](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42219539127) with a deliberately wrong assertion. The throwaway branch is kept at that red commit as evidence and is not merged. Now on `main` |
| 3 | green | 2026-11-06 | [42223050145](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42223050145) | FFUI semantic palette, type/space/radius/elevation tokens, 12 primitives, component gallery, 19 text/background contrast pairs, 12 component image snapshots and gallery screenshots. Green run executed 10 unit tests (WCAG AA contrast and snapshot hashes) and 2 UI tests (gallery sections and launch smoke). Now on `main` |
| 4 | green | 2026-11-06 | [42230744875](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42230744875) | Adaptive three-zone shell (tools, viewport, inspector), collapsible panels, width-driven breakpoints 640/820/1024/1366 pt, `UISceneSizeRestrictions` at 640×480 pt, five-width layout snapshot tests and a five-width XCUITest. Green run executed 15 unit tests and 4 UI tests, including the 640/700/820/1024/1366 width pass, collapse/restore, gallery and launch smoke. App code is unchanged after this run. The later test-only hardening commit (`43a1754`) adds window-containment assertions and screen-level captures; it was compiled and all 4 UI tests passed on the Intel gate [42257558856](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42257558856). Now on `main`; the arm64 `main` gate [42253433184](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42253433184) was cancelled after 15 minutes queued with zero steps, and the Intel `main` gate is reported below |
| 5 | green | 2026-11-06 | [42261681741](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42261681741) | `FFMath` core: `Vec2/3/4`, `Mat3/4`, `Quat`, `Plane`, `Ray`, `AABB`, `EPS 1e-9`, 132 deterministic property cases in 6 XCTest methods plus 6 acceptance tests, and inverse round-trips below 1e-12. The Intel gate executed 21 unit tests and 4 UI tests with zero failures. The first Intel run [42257558856](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42257558856) compiled the code and exposed two test defects (a negative normalization comparison and architecture-dependent image digests); both were fixed in `4900420` before this green run. On `main` at `5e37a1a`; the trunk gate [42265181937](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42265181937) also passed 21 unit and 4 UI tests, launched the app and uploaded the screenshot |

Status vocabulary:

- `pending` — not started.
- `wip` — branch open, gate not yet green.
- `green` — GitHub Actions `ios.yml` green and artifacts uploaded.
- `blocked` — stopped with a written reason (never silent).

## Branch history

`main` is a fast-forward of the verified phase chain. There are no merge commits and no squash:

| Phase | Branch | Tip | How it reached `main` |
| --- | --- | --- | --- |
| 0 | `phase-0-gate` | `7bc78d6` | fast-forward |
| 1 | `phase-1-app-target` | `c11f010` | fast-forward |
| 2 | `phase-2-test-gate` | `79bdc6c` | fast-forward |
| 3 | `phase-3-design-system` | `20be71d` | fast-forward |
| 4 | `phase-4-adaptive-shell` | `b4b8860` | fast-forward |
| 5 | `phase-5-math-core` | `5e37a1a` | fast-forward; tip contains verified code `4900420` and the PROGRESS commit |

The red `phase-2-gate-teeth` branch (`aa42234`) is deliberately not merged; it exists only as
evidence that the gate fails when an assertion breaks. The merged phase branches are deleted
after the mapping is recorded so the remote branch list stays readable.

## Known deviations

- `main` now carries phases 0–4 at `b4b8860` and Phase 5 at `5e37a1a`, not just `README.md`.
  The consolidation is a fast-forward, not a squash, so every phase commit remains inspectable.
  The arm64 gate for the first consolidated head
  [42253433184](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42253433184)
  passed the static job and was then cancelled after 15 minutes queued for a macOS runner
  (`runner_id: 0`, zero steps). The Intel trunk gate
  [42265181937](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42265181937)
  then passed: 21 unit tests and 4 UI tests with zero failures, a simulator launch
  (`com.shahroodazerov.facetforge`, PID 25374), and a 2064×2752 screenshot artifact.
- Phase 1's app was a branded launch-screen stub. The viewport begins in Phase 9, the document
  model in Phase 12, and tests in Phase 2. The Phase 1 gate proves build, install, launch and
  screenshot, not CAD behaviour.
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
  screenshots; the gallery screenshots are the device-level evidence. The digests differ by
  simulator architecture, so the test carries an arm64 and an x86_64 baseline, each recorded
  from a real run. A design change must update both tables.
- The GitHub Actions `ios` job no longer skips the build: it validates the project with
  `xcodebuild -list`, builds for an iPad simulator, installs, launches and screenshots.
- Phase 5 is a pure math module with no user-facing screen; the app still shows the Phase 5
  identity label and the Phase 4 shell. The math is not yet used by the viewport. Its green
  gate [42261681741](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42261681741)
  executed 21 unit tests and 4 UI tests with zero failures; the first Intel attempt
  [42257558856](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42257558856)
  had exposed the two test defects fixed in `4900420`.
- The PROGRESS updates after the verified trunk head are documentation-only and are marked
  `[skip ci]`; the verified trunk head is `5e37a1a` (run 42265181937). `ci-local.sh --static`
  passed on the docs head.
- The Phase 4 test-only hardening `43a1754` was compiled and executed by the Intel gate
  [42257558856](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42257558856):
  all 4 UI tests passed, so it is verified. The last green Phase 4 run predates it because the
  arm64 pool repeatedly cancelled the hardening runs
  [42232636599](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42232636599),
  [42237345115](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42237345115),
  [42239748028](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42239748028)
  and [42248706120](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42248706120)
  after 15 minutes queued, with `runner_id: 0` and zero steps. Those runs are capacity facts,
  not code failures; the Intel run is the compile-and-test proof.
- The arm64 macOS pool did not assign a runner to the `main` consolidation gate 42253433184 or
  the Phase 5 gate 42254738224; both were cancelled after 15 minutes with `runner_id: 0` and
  zero steps. The documented `macos-26-intel` fallback then assigned a runner immediately. The
  Phase 5 gate and the `main` gate therefore run on Intel; this is a capacity workaround, not a
  scope reduction. The static job passed on every gated head; documentation-only heads were
  checked locally with `ci-local.sh --static`.
