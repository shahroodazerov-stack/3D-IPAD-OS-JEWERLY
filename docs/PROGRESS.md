# Phase progress

One row per phase. A phase is only `green` when the GitHub Actions gate passed. `done-local`
means the work is committed but CI has not run; `wip` means the branch is open and the run is
not green yet. Update this file in the same commit as the phase.

| Phase | Status | Date | Gate run | Notes |
| --- | --- | --- | --- | --- |
| 0 | green | 2026-11-06 | [42210748897](https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY/actions/runs/42210748897) | Six dossiers, citation audit, repaired 200-phase plan, Phase 0 workflow/checkers, branding sheet. Gate green on branch `phase-0-gate`; not merged to `main` by design |
| 1 | pending | — | — | App target + build gate |
| 2 | pending | — | — | CI workflow and local verify script |
| 3 | pending | — | — | Design system |
| 4 | pending | — | — | Adaptive shell |
| 5 | pending | — | — | Math core |

Status vocabulary:

- `pending` — not started.
- `wip` — branch open, gate not yet green.
- `green` — merged, GitHub Actions `ios.yml` green, artifacts uploaded.
- `blocked` — stopped with a written reason (never silent).

## Known deviations

- The repository remote `main` contains only `README.md` (commit `1a8d68b`). Phase 0 work is
  committed on a branch, not merged into `main` without review.
- Phase 0 is green on `phase-0-gate` (run 42210748897) and deliberately not merged to `main`
  without review, per the Phase 0 note in the plan.
- The `ios` job is green but skips the Xcode build/simulator steps until Phase 1 adds
  `FacetForge.xcodeproj`; Phase 0 proves the static gate, not an iOS build.
- `.github/workflows/ios.yml` exists in Phase 0. Until Phase 1 adds `FacetForge.xcodeproj`, the
  iOS job detects the missing project, prints a notice and runs only the static gate.
