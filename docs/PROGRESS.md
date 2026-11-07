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
| 6 | green | 2026-11-06 | [42273691227](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42273691227) | `FFCurves.swift`: `Bezier2D`, rational `NURBS2D`, `Curve2D`, `CurvePath2D`, analytic derivatives, 16-point Gauss–Legendre arc length with adaptive panels, split/reverse/join/transform and closest-point search. Ten `CurveKernelTests` methods hold 20 golden curves to 1e-6 and 1,000 random closest-point queries to 1e-7. Gate executed 31 unit and 4 UI tests with zero failures. The first run [42270092334](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42270092334) failed to compile the second-derivative expression at `769ae35`; `b64088b` split it. `9227a12` also brackets endpoint minima after a local 1,000-query reference check. On `main` at `9227a12`; trunk gate [42277731911](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42277731911) passed 31 unit and 4 UI tests and launched PID 19027 with a 2064×2752 screenshot |
| 7 | green | 2026-11-06 | [42277777740](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42277777740) | `FFMeshes.swift`: indexed triangle mesh, welded vertex set, half-edge adjacency, manifold/watertight/orientation predicates, area-weighted normals, AABB bounds and signed volume, median-split `MeshBVH` ray casting. Six `MeshKernelTests` methods classify 25 fixtures, cover boundary and non-manifold counts, welding, normals and volume, 10,000 BVH/brute-force ray pairs and the empty mesh. Gate executed 37 unit and 4 UI tests with zero failures. Fast-forwarded to `main` at `8f36b36`; trunk gate [42289181614](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42289181614) passed 37 unit and 4 UI tests with zero failures, launched PID 21430 and captured a 2064×2752 screenshot. The first trunk dispatch [42281233168](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42281233168) hung in the test step for over 46 minutes without producing a log and was cancelled; it is an infrastructure hang, not a code failure |
| 8 | green | 2026-11-06 | [42304119386](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42304119386) | `FFTessellation.swift`: chordal and angular tessellation, display/export LOD, triangle budgets, closed and open curve paths, arc-length and deviation measurement. Eight `TessellationTests` methods prove that a 20 mm circle at 0.005 mm chordal is exactly 100 segments, all 20 sampled arc deviations stay below 5 µm, adaptive budgets are bounded, closed paths keep their seam and invalid quality settings are rejected. Gate executed 45 unit and 4 UI tests with zero failures, launched PID 34107 and captured a 2064×2752 screenshot. Fast-forwarded to `main` at `e6d55f9`. The earlier `b479466` attempts in run 42296551133 failed twice without a geometry failure: first the artifact upload timed out after all 45+4 tests passed, then the Phase 4 collapse test sampled the inspector before SwiftUI removed it; `e6d55f9` replaces that check with a disappearance predicate. Trunk gate is reported below |
| 9 | green | 2026-11-07 | [42304186052](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42304186052) | Metal viewport bootstrap: `FFCamera` perspective/orthographic projections, `FFCameraNavigation` named views and frame-all, an `MTKView` host with grid, world axes, MSAA 4×, sRGB output and a 0.5 s FPS HUD. The run on `phase-9-metal-viewport` at `ba95eae` executed 56 unit tests and 4 UI tests with zero failures, launched `com.shahroodazerov.facetforge` as PID 36065 and captured a 2064×2752 screenshot. The two later fixes in the rebased chain (`c1234b0` lets the Metal surface fill the viewport, `57b6015` repairs the camera test) are covered by the Phase 10 gate below. Now on `main`. |
| 10 | green | 2026-11-07 | [42322972031](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42322972031) | Camera and navigation: orbit/pan/pinch/focus with pitch and yaw clamps, cursor-anchored zoom, orthographic/perspective switching, named views, and 11 `CameraNavigationTests` plus a UI test that orbits, pinches and changes projection while reading the camera state back. The gate ran at `677f8a2` (Phase 10 code plus the arm64 runner change below) and executed 67 unit tests and 5 UI tests with zero failures, launched PID 24900 and captured a 2064×2752 screenshot. The Intel attempt [42319162840](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42319162840) passed all 67 unit tests but four UI queries timed out after 2–5 minutes each while the simulator took 8 minutes to boot. Now on `main`. |
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
| 6 | `phase-6-curve-kernel` | `9227a12` | fast-forward; the tip is the verified code |
| 7 | `phase-7-mesh-kernel` | `8f36b36` | fast-forward; tip contains verified code `704a7d8` and the Phase 6/7 PROGRESS commit |
| 8 | `phase-8-tessellation` | `e6d55f9` | fast-forward; verified code `b479466` plus the test-only collapse-wait fix `e6d55f9` |
| 9 | `phase-9-metal-viewport` | `ba95eae` | fast-forward of the rebased commits `04157c7`, `c1234b0`, `57b6015`; the original tip was green separately, and the two later fixes are covered by the Phase 10 gate |
| 10 | `phase-10-camera-navigation` | `8322ec1` | fast-forward; its gate ran on `677f8a2`, which adds only the arm64 workflow change |

The red `phase-2-gate-teeth` branch (`aa42234`) is deliberately not merged; it exists only as
evidence that the gate fails when an assertion breaks. The merged phase branches are deleted
after the mapping is recorded so the remote branch list stays readable.

## Known deviations

- `main` now carries phases 0–10. Phases 0–4 were consolidated with a fast-forward from
  `b4b8860`, Phase 5 from `5e37a1a`, Phase 6 from `9227a12`, Phase 7 from `704a7d8`, and Phase 8 from `e6d55f9`.
  No commit was squashed away, so every phase commit stays inspectable. The Phase 6 trunk
  gate [42277731911](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42277731911)
  passed 31 unit and 4 UI tests, launched `com.shahroodazerov.facetforge` as PID 19027 and
  captured a 2064×2752 screenshot. The arm64 gate for the first consolidated head
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

- Phase 6 and Phase 7 are pure math modules with no user-facing screen. The app still shows
  the Phase 7 identity label and the Phase 4 shell; the curve and mesh kernels are not yet used
  by the viewport (that begins with tessellation and rendering in Phases 8–9).
- Phase 6 needed two corrections before green. Run 42270092334 failed at `769ae35` because the
  Swift compiler could not type-check the nested second-derivative expression in reasonable
  time; `b64088b` split it into named intermediates. Run 42271824031 was cancelled when the
  fix push superseded it, not for capacity. While that run was in flight, a local 1,000-query
  reference check found that closest-point search ignored minima at a curve endpoint; `9227a12`
  adds endpoint brackets. The green gate then executed `CurveKernelTests` for 10 tests and the
  full suite for 31 unit and 4 UI tests with zero failures.
- Phase 7 passed on its first gate: 37 unit tests (including 6 `MeshKernelTests`) and 4 UI
  tests with zero failures. No capacity cancellation occurred on either phase; both gates ran
  on the documented Intel image after the arm64 pool had failed to assign runners earlier.
- PROGRESS updates after a verified trunk head are documentation-only and marked `[skip ci]`.
  The latest code-and-docs trunk proof before this table update is Phase 7 at `8f36b36`
  (run 42289181614); `ci-local.sh --static` and the validators run on every docs head.
- The Phase 7 trunk gate was green on its second dispatch, 42289181614, at `8f36b36`:
  37 unit tests (including the 6 `MeshKernelTests`) and 4 UI tests with zero failures, a
  simulator launch (`com.shahroodazerov.facetforge`, PID 21430) and a 2064×2752 screenshot.
  The first dispatch 42281233168 entered the test step at 19:45:57 and produced no log or
  step completion for over 46 minutes on an Intel runner that stopped reporting; the cancel
  request was accepted only when the replacement dispatch started. That run is recorded as
  an infrastructure hang, not as a code failure, and its result is not claimed.
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

- The Phase 9 and 10 gates ran on two different runner images. Phase 9's original tip
  `ba95eae` was green on the Intel image in 42304186052 with 56 unit and 4 UI tests.
  When the same suite was gated on 2026-11-07, the Intel image needed 6–8 minutes to boot
  an iPad simulator and then timed out ordinary accessibility snapshots: run 42319162840
  passed every one of the 67 unit tests but failed four UI tests with `Failed to get
  matching snapshots` after 2–5 minutes per query. That is a runner-capability fact, not
  a code failure, so `677f8a2` moves the `ios` job back to `macos-26` (arm64) and adds
  per-test timeouts that bound a future hang. The arm64 gate 42322972031 then passed
  67 unit and 5 UI tests, launched PID 24900 and captured 2064×2752 in thirteen minutes.
  Two Intel runs started before that decision were cancelled rather than left to their
  45-minute timeouts: 42320665305 (Phase 11, `a069284`) and 42321171618 (Phase 12,
  `546b1c5`). They are not test results and are not claimed as green.
- The Phase 9 / Phase 10 split is honest: the Phase 9 row cites the run that gated the
  phase's original tree (`ba95eae`). Two subsequent fixes were required to land it in the
  consolidated trunk (`c1234b0` removed a conflicting frame modifier and `57b6015` passed
  the yaw delta the clamp test expects), and those two commits are verified by the Phase 10
  gate rather than by a Phase 9 rerun. No app behaviour is claimed beyond what those runs
  executed.
- Phase 8 is a pure tessellation module with no new screen; the app still shows the Phase 8 identity label over the Phase 4 shell. Its green gate [42304119386](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42304119386) executed 45 unit tests (including 8 `TessellationTests`) and 4 UI tests with zero failures, launched `com.shahroodazerov.facetforge` as PID 34107 and captured a 2064×2752 screenshot. The `b479466` attempts in run 42296551133 were not geometry failures: the first passed all tests then lost artifact upload to five GitHub `CreateArtifact` timeouts, and the rerun failed the Phase 4 collapse test because `waitForExistence` returns immediately for an element that is still present. `e6d55f9` adds a predicate wait for disappearance and is the verified code head. The Phase 8 test fix does not change app behaviour.
