# 00 — Consolidated findings, verified environment and constraints

**Pass:** research and environment reconnaissance (mission step 2) · **Date:** 2026-11-06
**Scope:** behavioural research on MatrixGold plus an honest audit of what this machine and this
repository can actually build. **This file does not contain a phase plan.** It records findings,
verified facts and constraints that the plan must respect.

**Plan status:** `docs/MASTER-PLAN.md` v1.1 was reconciled against this file on 2026-11-06. The
phase-by-phase decision trail is `docs/PLAN-RECONCILIATION.md`; this file remains the constraint
record, not a second plan.

**Verification vocabulary used here**

- **VERIFIED IN THIS ENVIRONMENT** — a command was run or a page was fetched during this pass,
  and the result is recorded below.
- **READ IN A SOURCE** — a public source states it; see the thread file and its citations.
- **UNVERIFIED / UNKNOWN** — not established, and not to be presented as fact.

---

## 1. How the research was done

Six parallel research threads were run against public material only:

| Thread | File | Outcome |
| --- | --- | --- |
| (a) UI/UX and interaction | `b-matrixgold-ux.md` | Existing dossier verified; added a verification subsection |
| (b) Core 3D modelling | `d-cad-kernel.md` | Existing dossier verified; added a verification subsection |
| (c) Jewelry tooling | `c-jeweler-domain.md`, `a-matrixgold-product.md` | Existing inventory verified; tool-level gaps recorded |
| (d) Rendering, materials, presets | `g-rendering-materials.md` | New |
| (e) Production and interchange | `h-production-interchange.md` | New |
| (f) Competitive and kernel landscape | `i-competitive-kernels.md` | New |

No vendor binary was installed, decompiled or executed. No vendor text, icon, screenshot,
material, HDRI, model or preset was copied. Every claim in the thread files carries a FACT,
VENDOR, TRADE, USER REPORT or INFERENCE label. Citation fetch results live in
`docs/evidence/link-status.md`.

---

## 2. Verified environment facts

### 2.1 This machine

| Fact | Evidence | Consequence |
| --- | --- | --- |
| Host is **Windows** (MINGW64 / Git Bash), not macOS | `uname -a` → `MINGW64_NT-10.0-26300 … Msys` | No native iOS build here |
| **No Xcode, Swift or simulator tools** | `which xcodebuild` / `swift` / `swiftc` / `xcrun` → not found; `xcodebuild -version` → command not found | **Cannot compile, test, launch or screenshot the app locally** |
| Python 3.15, Node 24.18, Git 2.56 available | `python --version`, `node --version`, `git --version` | Static checks and citation fetching can run locally |
| Workspace path contains a space | `pwd` → `/c/Users/shahr/Desktop/3D JEWERLY` | Quote paths in all scripts; already a documented caveat in `AGENTS.md` |
| Local Swift verification logs are absent | no DerivedData or `.build` products from a local Xcode run | Any future "build passed" claim must cite a CI run |

### 2.2 Git and GitHub

| Fact | Evidence | Consequence |
| --- | --- | --- |
| Remote is reachable | `git ls-remote --heads origin` returned `main` and `phase-2-gate-teeth` | Remote work is possible |
| Local `main` equals remote `main` | `git rev-parse HEAD` = `8404d5a…` = `origin/main` | No divergence at the start of this pass |
| The repository is **public** | The Actions run page fetched without authentication and returned HTTP 200 with the run summary | Unauthenticated readers can see the repo; treat every committed file as public |
| Write credentials work | `git push --dry-run origin main` → `Everything up-to-date` (no prompt, no auth error) | A push can be performed when the mission requires it |
| `gh` CLI is **not authenticated** | `gh auth status` → "You are not logged into any GitHub hosts" | Cannot inspect secrets, branch protection, workflow permissions or the API through `gh` |
| No `GH_TOKEN` / `GITHUB_TOKEN` in the shell | presence checks printed "unset" | No scripted API access; do not invent one |
| There are **4 uncommitted app files** from earlier work | `git status --short`: modified `FFMetalViewport.swift`; untracked `FFDemoScene.swift`, `FFRealityViewport.swift`, `FFSceneRendering.swift` | **Not mine, not touched.** This pass stages only its own docs |

**UNKNOWN:** branch protection rules, required reviewers, repository secrets, signing
certificates, App Store Connect access. None can be checked without authenticated API access.

### 2.3 GitHub Actions capability

| Fact | Evidence | Consequence |
| --- | --- | --- |
| The repo has a working iOS gate | `.github/workflows/ios.yml`: `static` on `ubuntu-latest`, `ios` on `macos-26`, Xcode 26.6 selection, iPad simulator discovery, `xcodebuild test`, test-count assertion, launch + screenshot, artifact upload | **Yes, GitHub Actions can build and test this iOS/iPadOS target** |
| A recent gate actually passed | Run **#55** for commit `f5742ec` (Phase 12): status **Success**, **12m 7s** total; `ios` job **11m 54s**; 12.1 MB `ios-results` artifact | The gate is not aspirational; it has executed |
| The gate refuses a zero-test green | The workflow greps for `Executed N tests, with 0 failures` and fails otherwise | A phase cannot pass by skipping tests |
| The gate runs on **arm64 macOS** | `runs-on: macos-26`; a comment records an Intel fallback that timed out UI snapshots | Runner choice is deliberate; do not silently switch images |
| Simulator builds are signing-free | `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO` | Device/TestFlight signing remains **unverified** |
| Runner capacity is occasionally flaky | `docs/PROGRESS.md` records arm64 cancellations with `runner_id: 0` and Intel UI-query timeouts | The plan must allow bounded retries and honest failure reporting |

**VERIFIED:** iOS/iPadOS builds and simulator tests run in this repo's Actions. **NOT VERIFIED:**
physical-device deployment, TestFlight, App Store submission, or GPU performance measurement.

### 2.4 Existing repository state

| Fact | Evidence | Consequence |
| --- | --- | --- |
| Phases 0–12 are green | `docs/PROGRESS.md` rows, each linked to a run | The mission is mid-execution, not at phase 0 |
| Phase 12 gate ran **87 unit tests and 5 UI tests** with zero failures | PROGRESS row for run 42326712561 | That is the current automated baseline |
| Implemented: math core, curves, meshes, tessellation, Metal viewport, camera, units, document/undo | `FacetForge/` tree and PROGRESS | Geometry and document foundations exist; no jewelry builders yet |
| A 200-row master plan already exists and is structurally validated | `docs/MASTER-PLAN.md`; `scripts/check-plan.sh` checks 200 rows, arcs and acceptance text | Do not rewrite it in this pass |
| Local static gate is runnable | `bash scripts/ci-local.sh --static` | Use it after docs changes |
| Full local gate cannot pass here | `scripts/ci-local.sh` exits **2** with "iOS build: SKIPPED (host is …)" | Never report local full-gate success |

---

## 3. Consolidated research findings

### 3.1 UI/UX and interaction (thread a)

- MatrixGold is a **Rhino 8 plug-in for Windows**, wrapped in an Office-like ribbon, a command
  search, dockable panels and a Rhino command line. Its power is the parametric graph, not the
  chrome. (READ IN SOURCE — `b-matrixgold-ux.md`)
- **Viewport Control Handles (VPCH)** — draggable in-viewport handles for parametric values — are
  the most transferable interaction idea. They complement sliders and typed values.
- **Dynamic Commands** is the editable per-command history stack; it is not a global MCAD feature
  timeline.
- Documented pain points: discovery is hard, Rhino knowledge is assumed, panels desync, the ribbon
  overflows on small screens, and render presets feel locked. These are design counters, not
  features to clone.
- **Contradiction to keep open:** one review says the app opens with a single maximised
  Perspective viewport; the earlier dossier says four-up is the default. Both are recorded; treat
  the true default as **unresolved** and do not build a claim on it.

### 3.2 Core 3D modelling (thread b)

- MatrixGold inherits Rhino's NURBS/B-rep, meshes, SubD (Catmull-Clark), booleans, fillets,
  sweeps, lofts and history. Clayoo supplies SubD. (READ IN SOURCE)
- Rhino's **default absolute tolerance is 0.01 mm**; the earlier dossier's "0.001 mm model
  tolerance" is a design choice, not a Rhino default. Keep them distinct.
- Booleans are Intersect → Split → Delete → Join and fail when an intersection loop is open
  (coincident seams, near-tangency, invalid geometry, loose tolerance). MatrixGold adds a
  **Nudge** retry and an "editable cutters" workflow; Nudge's algorithm is undocumented.
- History is per-command and **breakable** (`gvBreakHistory`); rebuild failures are real enough
  that the product ships global parametric off, pause-recalculate and mouse-up regeneration.
- There is **no easy mesh → NURBS conversion** in Rhino. This supports the existing
  mesh-authoritative solid decision, not a full B-rep rewrite.

### 3.3 Jewelry tooling (thread c)

- The real ring pipeline is **Ring Rail (a curve, not a solid) → Profile Placer/Sweep → Gem on
  Ring Rail → Head/Bezel/Halo → Prong/Channel/Pavé → Boolean → Ring Resizer → report/export**.
- "Ring Builder" is marketing shorthand; no standalone command by that name is documented.
- Ring Rail became a **degree-2** curve so the result is perfectly round. Ring Resizer exposes
  tolerance and angle, and resizes gems, prongs and cutters with the ring.
- **Milgrain** is named in tutorials but its parameters are not publicly documented. Treat any
  milgrain implementation as our own design, not parity.
- Tech Report/Gem Report are first-class production outputs (counts, weights, gem map), not
  afterthoughts.

### 3.4 Rendering and materials (thread d)

- Render Studio is a **customised Rhino Cycles**, not a bespoke engine; quality presets map to
  15/50/500/1500 samples, with bounce limits and render channels. (READ IN SOURCE —
  `g-rendering-materials.md`)
- Materials are a curated library over a PBR shader, assigned by layer, with render styles, HSL
  gem controls and a per-material specific gravity. Vendor notes admit advanced render materials
  are not editable outside rendering.
- iJewel3D is a **separate real-time WebGL visualiser** with a custom gem shader (refraction,
  dispersion, RI 2.60 default, ray bounces 4–5, up to 16), not a path tracer. BatchX is local,
  not cloud.
- **No cloud rendering** was found. "Photoreal in seconds" refers to GPU/offline or the
  visualiser, not live path tracing.
- iPadOS gap: RealityKit gives PBR, IBL, offscreen `RealityRenderer`, Metal compute/ray tracing
  and MetalFX, but has **no documented gem refraction/dispersion model**. Credible diamond
  "fire" needs a custom Metal shader or baked variants.

### 3.5 Production and interchange (thread e)

- MatrixGold documents **STL, 3DM and OBJ** as outputs. Rhino's other exporters exist but are not
  MatrixGold-supported; do not claim 3MF/SLC/STEP parity.
- Production data is **geometry plus a report**: Tech Report PDF/CSV (weights in g/dwt), Gem
  Report TXT, gem map, 3D gem labels, Scoop hollowing and Thickness Analysis in 4.0.
- No native shrink scale, sprue builder or 3MF pipeline was documented; those remain manual trade
  steps.
- Casters require manifold, watertight, correctly scaled meshes. Minimum walls vary by caster
  (0.40–1.0 mm); there is no single standard. Finishing removes 0.10–0.20 mm.
- Weight = volume (mm³) × SG ÷ 1000. Estimates exclude sprue, porosity and finishing loss.
- JewelCAD's documented "STL without Boolean data" and a bureau's preference for native `.jcd`
  show why a **proven watertight** mesh is a differentiator.

### 3.6 Competition and kernels (thread f)

- **No incumbent ships a native iPadOS jewelry CAD authoring app.** ZBrush for iPad is
  sculpting-first; Onshape/Fusion mobile are generic MCAD/viewer experiences. That is the gap.
- Price anchors: MatrixGold $5,995 with Rhino / $5,495 without plus $695/yr; 3Design ~$6k class;
  JewelCAD dongle licensing; ZBrush iPad ~$90/yr; Onshape $1,500–2,500/user/yr; Fusion $680/yr.
- Licence reality: **OCCT (LGPL + App Store static-linking problem) and CGAL (GPL/LGPLv3) are
  blocked without a commercial licence or counsel.** Permissive options: Manifold (Apache-2.0),
  openNURBS (I/O only), libigl MPL core, Draco, OpenVDB, USD, Assimp (BSD-3).
- iPadOS memory is a per-process jetsam limit (unpublished, device-varying); thermal state forces
  LOD/frame-rate reduction. CAD meshes need streaming and display/export LOD separation.

---

## 4. What this means for the plan

These are constraints, not new phases. The existing 200-phase plan must be read against them.

1. **All build/test evidence is CI evidence.** This host cannot compile Swift. A phase that says
   "build and test" is only green when a linked Actions run passes. Local work can be reviewed,
   formatted, statically checked and citation-audited; it cannot be claimed as built.
2. **The plan must keep every acceptance runner-executable.** The existing `check-plan.sh` already
   requires `CI:` prefixes; device-only or human-only checks must go through a `docs/evidence/`
   record, and a missing/failed record is red.
3. **Do not switch runner images silently.** `macos-26` (arm64) is the verified image. Intel
   fallbacks caused multi-minute simulator boots and UI-query timeouts; if capacity forces a
   change, record the run id and the reason.
4. **Zero-test greens are forbidden.** The workflow asserts executed tests; keep that assertion.
5. **No unlicensed dependency enters the app.** Before adding a library, record its licence and
   App Store compatibility in `docs/legal/provenance.md`. OCCT/CGAL/GPL code are blocked unless
   counsel or a commercial licence changes that.
6. **Renderer scope must be honest.** Do not promise RealityKit gem refraction. Either budget a
   custom Metal gem shader (and measure it on hardware) or ship labelled baked variants.
7. **Manufacturing defaults must be sourced and overridable.** Vendor minima are not standards;
   the UI must name the source and allow a caster profile.
8. **Trademark and copyright constraints shape naming and UI** (see section 5). Behavioural parity
   is allowed; copying expression is not.
9. **Cost and time are real.** Public-repo standard runners are free; if the repo ever becomes
   private, a ~12-minute gate costs roughly $0.75 at the list price recorded in
   `f-engineering-delivery.md` (research figure, not verified billing). 200 phases plus reruns is
   a significant CI budget.
10. **The mesh-authoritative kernel decision stands.** Nothing in this pass justifies a full
    trimmed-NURBS B-rep kernel; the evidence (Rhino tolerance, boolean failure modes, no
    mesh→NURBS path, iPad memory) supports a hybrid exact-parametric front end over mesh solids.

---

## 5. What the plan must NOT do

This section is binding for the plan and for every later phase.

### 5.1 No copying of expression or assets

- Do **not** copy, extract, decompile, disassemble, memory-scrape or otherwise reverse-engineer
  MatrixGold, Rhino, Clayoo, iJewel3D or any vendor binary. Behavioral research from public
  documentation is the only permitted method.
- Do **not** copy vendor source code, shader code, icons, cursors, ribbon artwork, screenshots,
  PDFs, manual text, tutorial text, UI strings, sample files, gem models, materials, HDRIs or
  preset libraries.
- Do **not** reproduce the ribbon's exact layout, icon set, colour scheme or panel arrangement as
  trade dress. Functional ideas (parametric handles, history panel, layer assignment) are fair to
  re-express in our own visual language.
- Do **not** ship any asset whose licence is not recorded in `docs/legal/provenance.md`.

### 5.2 No trademark or affiliation claims

- Do **not** use **MatrixGold, Gemvision, Stuller, Rhino, Matrix, RhinoGold, JewelCAD, 3Design,
  ZBrush** (or confusingly similar marks) in the product name, bundle identifier, icon, domain,
  App Store title, subtitle, keywords, screenshots or marketing.
- Do **not** claim affiliation, endorsement, certification, compatibility or "official port".
- Nominative reference is acceptable only in internal research/legal documents, with a clear
  disclaimer that the project is unaffiliated. It must not appear in shipped UI or store metadata.
- Do **not** market the app as "exactly like MatrixGold". The honest claim is behavioural
  workflow parity, independently implemented.

### 5.3 No false standards, legal or capability claims

- Do **not** present vendor guidance as ISO/ANSI/GIA standards. Every minimum wall, prong
  diameter, bead size and shrink figure must carry its source and an "overridable default" label.
- Do **not** claim ISO 8653 or GIA compliance unless the implementation actually matches the
  published definitions and a test proves it.
- Do **not** claim App Store readiness, device performance, thermal safety or casting accuracy
  without a recorded measurement. Simulator results are correctness-only.
- Do **not** add telemetry, cloud rendering, accounts or data collection without a privacy review
  and a disclosed policy.

### 5.4 No licence violations

- No **GPL/AGPL** code in the shipping binary.
- No **LGPL** code (including OCCT) without counsel-approved relink compliance or a commercial
  licence. Absent that, it is out of scope.
- No vendor SDK, font, HDRI or texture without a recorded licence.
- Do not assume public GitHub visibility grants rights to third-party assets.

### 5.5 No unsafe repository behaviour

- Do not commit another agent's or the user's uncommitted work. Stage only the files this pass
  created or edited.
- Do not force-push, rewrite history, delete branches or change repository settings as part of
  research.
- Do not commit secrets, tokens, signing material or `.env` files.

---

## 6. Verification log for this pass

| Check | Result | Evidence |
| --- | --- | --- |
| Remote reachable | PASS | `git ls-remote --heads origin` listed two branches |
| Local/remote in sync at start | PASS | both `8404d5a` |
| Repository public | PASS (observed) | unauthenticated run page returned HTTP 200 |
| Push credential available | PASS | `git push --dry-run` reported up to date |
| Xcode/Swift present | **FAIL (expected)** | commands not found |
| CI workflow present and capable | PASS (read) | `ios.yml` includes build, test, launch, screenshot |
| Recent CI gate green | PASS (observed) | run #55, 12m 7s, Success |
| `gh` authenticated | **NO** | `gh auth status` |
| Branch protection / secrets | **UNKNOWN** | cannot query without auth |
| Local full iOS gate | **NOT RUN / IMPOSSIBLE** | would exit 2 on Windows |
| Static gate after docs edits | see the commit/CI record | `bash scripts/ci-local.sh --static` |
| Citation fetch audit after new files | see `docs/evidence/link-status.md` | `python scripts/check-links.py` |

**Explicit non-claims:** this pass did not build the app, did not run the iOS test suite, did not
verify device performance, did not verify App Store legality, and did not verify branch
protection. It produced documentation only.

---

## 7. Open questions carried forward

1. Which default viewport layout MatrixGold actually ships (conflicting evidence).
2. MatrixGold's exact alloy/gem preset list, Render Studio denoising behaviour and cloud status.
3. The Nudge algorithm, history storage format and exact tolerance overrides.
4. Milgrain parameters and whether it is a builder or a bead-array workflow.
5. Which casting houses and file formats the target users actually use.
6. Real iPad thermal/jetsam behaviour and custom gem-shader throughput.
7. App Store legal review of the dependency set and the trademark/naming position.

None of these blocks writing code, but each must be resolved before a claim depends on it.
