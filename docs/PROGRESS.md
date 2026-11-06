# Phase progress

One row per phase. A phase is only `green` when the GitHub Actions gate passed. `done-local`
means the work is committed but CI has not run; `wip` means the branch is open and the run is
not green yet. Update this file in the same commit as the phase.

| Phase | Status | Date | Gate run | Notes |
| --- | --- | --- | --- | --- |
| 0 | green | 2026-11-06 | [42210748897](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42210748897) | Six dossiers, citation audit, repaired 200-phase plan, Phase 0 workflow/checkers, branding sheet. Gate green on branch `phase-0-gate`; not merged to `main` by design |
| 1 | green | 2026-11-06 | [42211739495](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42211739495) | Hand-authored `FacetForge.xcodeproj`, shared scheme, SwiftUI launch screen. Gate built `FacetForge.app`, installed and launched `com.shahroodazerov.facetforge`, and uploaded a 2064×2752 screenshot. App is a stub screen; viewport Phase 9, document Phase 12, tests Phase 2. Branch-green, not merged |
| 2 | pending | — | — | CI workflow and local verify script |
| 3 | pending | — | — | Design system |
| 4 | pending | — | — | Adaptive shell |
| 5 | pending | — | — | Math core |

Status vocabulary:

- `pending` — not started.
- `wip` — branch open, gate not yet green.
- `green` — GitHub Actions `ios.yml` green and artifacts uploaded. Phases 0 and 1 are
  branch-green by design; the plan requires review before `main` is merged.
- `blocked` — stopped with a written reason (never silent).

## Known deviations

- The repository remote `main` contains only `README.md` (commit `1a8d68b`). Phase 0 work is
  committed on a branch, not merged into `main` without review.
- Phase 0 is green on `phase-0-gate` (run 42210748897) and deliberately not merged to `main`
  without review, per the Phase 0 note in the plan.
- Phase 1 is green on `phase-1-app-target` (run 42211739495); the app is a branded
  launch-screen stub. The viewport begins in Phase 9, the document model in Phase 12, and tests
  in Phase 2. The Phase 1 gate proves build, install, launch and screenshot, not CAD behaviour.
- The GitHub Actions `ios` job no longer skips the build: it validates the project with
  `xcodebuild -list`, builds for an iPad simulator, installs, launches and screenshots.
