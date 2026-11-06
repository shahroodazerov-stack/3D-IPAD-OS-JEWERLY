# FacetForge — 200-Phase Master Implementation Plan

**Version:** 1.0 · **Date:** 2026-11-06 · **Owner:** shahroodazerov-stack
**Repo:** https://github.com/shahroodazerov-stack/3D-IPAD-OS-JEWERLY
**Inputs:** six research dossiers in `docs/research/` (A product, B UX, C domain, D kernel, E platform/legal, F delivery)
**Status:** specification complete, no application code written yet.

---

## 0. Mission

Build **FacetForge**, an original iPadOS-first 3D CAD application for jewellers that reaches
functional parity with Gemvision MatrixGold's *jewellery workflow* — parametric ring building,
gem and setting generators, manufacturing output — using only clean-room knowledge, original
code and original assets.

"Parity" means: a jeweller can do the eight-step MatrixGold quick-start workflow
(ring rail → gem → head → profiles → sweep → resize → stone swap → render) in FacetForge, and can
hand the result to a casting house as a watertight STL/3MF. It does **not** mean pixel-identical
UI, and it explicitly excludes copying names, icons, libraries, help text or code.

### Product decisions (locked)

| Decision | Value | Rationale |
| --- | --- | --- |
| Product name | **FacetForge** | Original, descriptive of gem facets + metalwork; no use of Gemvision/Stuller/Rhino marks. Full trademark screen in phase 194 |
| Bundle id | `com.shahroodazerov.facetforge` | Owner-controlled reverse-DNS |
| Platforms | iPadOS 26.0+ primary; iPhone 26.0+ as read/edit-lite companion from phase 167 | iPad is the working surface; Stage Manager and Pencil are first-class |
| Orientation | Any; no fullscreen lock (Apple deprecated opt-out on iPadOS 26) | Dossier E |
| Units | Millimetres internally, double precision; display units mm / inch / US ring size | Dossier C |
| Connectivity | Fully offline; no account, no telemetry, no cloud render | Privacy + trust; no backend to operate |
| Kernel | Hybrid: exact parametric curves/surfaces → watertight mesh solids (ADR-001) | Dossier D |
| Render | RealityKit viewport behind a renderer protocol; Metal studio renderer later (ADR-002) | Dossier E |
| Minimum device | iPad Air (M3, 8 GB) as performance floor; iPad Pro (M5) as target | Dossier E |
| Money model | One-time purchase, no subscription (decision; not a phase deliverable) | Differentiator vs $695/yr membership |

### Non-negotiables

1. **Clean room.** No decompilation, no vendor binaries, no copied assets, no vendor marks. Spec
   comes from `docs/research/` and public docs only. Provenance is logged.
2. **Gate.** Every phase ends with the GitHub Actions build + unit tests + UI smoke **green**,
   or — only where the acceptance names one — a valid `docs/evidence/phase-NNN.json` record for
   a proof that cannot run on a hosted runner. A red gate blocks the next phase; there is no
   "fix it later" lane.
3. **Cache discipline.** All local caches live in `.dev-cache/` per `AGENTS.md`. Xcode
   DerivedData, SwiftPM caches and simulator artefacts are redirected or documented as exceptions.
4. **Precision.** Geometry is double precision in the kernel; tessellation is tolerance-driven;
   manufacturing exports are mm and verified watertight.
5. **Accessibility.** Every interactive control has a label, a keyboard path and a 44 pt target
   from the phase that introduces it — not retrofitted at the end.
6. **No placeholder phases.** Every phase below names deliverables and a machine-checkable proof.
7. **Scope discipline.** Phases build on prior phases only; no phase reopens a shipped module
   without a tracked regression test.

---

## 1. How to read this plan

### Phase numbering

- **Phase 0** is the pre-condition gate (repository, CI, naming, legal protocol). It is *not*
  counted among the 200.
- **Phases 1–200 are the 200 implementation phases**, exactly 200 numbered entries in §3.
- Each phase is a single agent-sized work unit: one branch, one PR-sized change, one gate run.

### Phase anatomy

| Field | Meaning |
| --- | --- |
| **Goal** | One line: what exists after the phase that did not before |
| **Deliverables** | Concrete files/modules/screens produced |
| **Acceptance** | The check that proves it — a command, test name, metric, or screenshot assertion |
| **Deps** | Phase numbers that must already be green |
| **Axis** | `spec` (behaviour/data fidelity) · `design` (UI/UX) · `correctness` (kernel/tests) · `concision` (performance/simplification) |

### Figure provenance (standards vs trade rules)

Every numeric default carries one of four labels, matching dossier C:

- **FACT / standard** — published by a standards body or primary reference (ISO 8653 ring
  sizing, GIA facet ranges). Tests may assert it as a correctness requirement.
- **VENDOR** — one supplier's production guidance (Stuller wall/prong minima, Formlabs cast
  walls). It is a configurable default; the test asserts the configured value and that the
  warning names the source, not that the number is universal.
- **TRADE** — an industry rule of thumb (halo spacing, carat factors, shrinkage ranges). It is
  surfaced as a default with a range and never described as a standard.
- **INFERENCE** — our own design decision (shank preset dimensions, tolerance policy).

Phase 104 enforces only the `>= 0.15 mm` lower bound of the 0.15–0.30 mm halo band. The upper
figure and the 0.30 mm "thin wall" in phases 110/147 are test-fixture values, not manufacturing
standards.

### Definition of done (every phase)

1. Code merged to `main` with tests committed alongside.
2. `bash scripts/ci-local.sh --static` reproduces the static gate on any host; the full
   `bash scripts/ci-local.sh` runs the iOS build on macOS and exits 2 elsewhere rather than
   claiming a green build.
3. GitHub Actions `ios.yml` green: build, unit tests, UI smoke, `.xcresult` + screenshot artifacts
   (the Phase 0 skeleton skips the build until Phase 1 adds the Xcode project).
4. New public types documented with doc comments; ADR added if an architectural choice was made.
5. `docs/PROGRESS.md` row appended: phase number, date, gate run URL, anything deferred.
6. No new warnings, no `TODO` in shipping paths, no disabled tests.
7. If the phase touched Xcode/SwiftPM caches, `bash scripts/cache-audit.sh` shows no growth in
   `~/Library/Developer/Xcode/DerivedData`.

### Architecture at a glance

```
SwiftUI (FFUI) ── FacetForgeApp ── DocumentSession
      │                                  │
      ├── ViewportRendering protocol ────┤
      │        ├── RealityKitViewport    │
      │        └── MetalStudioViewport   │
      │                                  │
      ├── FFJewelry (ring, heads, gems, settings, manufacturing rules)
      │        │
      ├── FFDocument (scene tree, history, file format, undo)
      │        │
      ├── FFSolids (booleans, shell, fillet, validate, mesh repair)
      │        │
      ├── FFGeometry (curves, surfaces, tessellation, BVH, picking)
      │        │
      └── FFMath (vectors, matrices, tolerances, predicates)
```

- **ADR-001** hybrid parametric → mesh-solid kernel.
- **ADR-002** RealityKit viewport behind `ViewportRendering`; Metal for studio/offline render.
- **ADR-003** raw Pencil `UITouch` pipeline; PencilKit only for markup.
- **ADR-004** clean-room protocol; no vendor assets or marks.
- **ADR-005** iPadOS 26+, iPhone companion from phase 167.
- **ADR-006** one scene per document; adaptive 640 pt minimum; no fullscreen lock.

### Milestones

| Arc | Phases | Theme | Exit criterion |
| --- | --- | --- | --- |
| 1 | 1–12 | Foundation, CI, math, document | App runs in simulator with a saved/undone scene |
| 2 | 13–24 | Viewport and interaction | Orbit, pick, gumball, snap, measure at 60 fps |
| 3 | 25–38 | Document, files, data | Round-trip file format, browser, templates |
| 4 | 39–56 | Curve and sketch modelling | Constraint sketch → usable profiles |
| 5 | 57–78 | Solid modelling | Booleans, shell, fillet, feature tree, 200 golden solids |
| 6 | 79–94 | Gemstones | Nine cuts, carat estimates, stone library |
| 7 | 95–114 | Ring builder | Eight-step quick-start workflow reproduced |
| 8 | 115–128 | Assemblies and libraries | Instanced parts, anchors, patterns |
| 9 | 129–146 | Rendering and presentation | Studio-quality stills and turntable |
| 10 | 147–160 | Manufacturing | Validated STL/3MF/OBJ + print report |
| 11 | 161–178 | iPad UX, Pencil, accessibility | VoiceOver/keyboard complete, onboarding |
| 12 | 179–200 | Performance, reliability, release | v1.0 shipped |

---

## 2. Phase 0 — repository and CI gate (not counted in the 200)

**Goal:** the workspace is a governed, buildable repo before any feature work.

**Deliverables**
- `AGENTS.md` ground rules (§ cache discipline, taking precedence over everything).
- `scripts/dev-env.sh`, `dev-env.ps1`, `run.sh`, `cache-audit.sh`.
- `.github/workflows/ios.yml`: `macos-26`, Xcode 26.6 when present, plan/workflow checks on
  every push/PR/manual run, signing-free iPad simulator `test` plus launch screenshot once the
  project exists, artifacts, concurrency, 45-minute timeout.
- `scripts/ci-local.sh` local mirror; `scripts/check-workflow.sh` structural validator
  (`actionlint` when installed); `scripts/check-plan.sh` invariant checker.
- `scripts/check-evidence.sh` plus `docs/evidence/` schema for the few proofs that genuinely
  need a physical device or external review.
- `docs/research/` six dossiers; `docs/MASTER-PLAN.md` (this file); `docs/PROGRESS.md` seed row.
- `docs/legal/provenance.md` with the clean-room protocol and the list of sources used.
- Branding sheet: name, bundle id, palette seed, icon concept (original).
- ADR-001…006 recorded in `docs/adr/README.md`.

**Acceptance:** `git remote -v` shows `origin`; `.github/workflows/ios.yml` exists and passes
`scripts/check-workflow.sh`; `scripts/ci-local.sh --static` passes; `docs/research/` has six
files; `docs/MASTER-PLAN.md` contains exactly 200 continuous phase rows with backward-only
dependencies (checked by `scripts/check-plan.sh`); every Phase 0 deliverable listed above exists;
no file outside `.dev-cache/` holds generated cache data.

**Note:** the remote `main` currently contains only `README.md` (commit `1a8d68b`). Phase 0 is
pushed on its own branch for the first Actions run; it is not merged to `main` without review.

---

## 3. Phases 1–200

### Arc 1 — Foundation and CI (phases 1–12)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 1 | A signed-free iPad app target builds and launches | `FacetForge.xcodeproj`, app target `FacetForge`, SwiftUI `App`, deployment target iPadOS 26.0, bundle id `com.shahroodazerov.facetforge`, shared scheme | CI: xcodebuild build for the iPad simulator with signing disabled succeeds and the built app launches in the simulator with a screenshot artifact | 0 | spec |
| 2 | The gate exists and is trustworthy | `.github/workflows/ios.yml` (build, unit test, UI smoke, xcresult + screenshot artifacts, concurrency cancel-in-progress, pinned image/Xcode), `scripts/ci-local.sh`, `scripts/check-plan.sh`, `docs/PROGRESS.md` | CI: Workflow green on `main`; artifacts contain `Test.xcresult` and `smoke.png`; `cache-audit.sh` shows no growth in `~/Library/Developer/Xcode/DerivedData` after a local build | 1 | correctness |
| 3 | Design system foundation | `FFUI` tokens (colour, type scale, spacing, radii, elevation), dark-first palette, 12 primitives (button, chip, field, slider, segmented, sheet, panel, list row, toast, tooltip, toolbar, empty state), component gallery screen | CI: Component snapshot tests pass; automated contrast check meets WCAG AA 4.5:1 for text pairs; gallery screenshots archived | 1 | design |
| 4 | Adaptive app shell | Three-zone layout (tools, viewport, inspector), collapsible panels, breakpoints 640/820/1024/1366 pt, Stage Manager resize behaviour, `UISceneSizeRestrictions` | CI: UI test resizes through five widths with no clipped or overlapping controls; layout snapshots stored | 3 | design |
| 5 | Math core | `FFMath`: `Vec2/3/4`, `Mat3/4`, `Quat`, `Plane`, `Ray`, `AABB`, tolerance + comparison helpers, `EPS 1e-9` policy | CI: 120+ property tests green; matrix/quaternion inverse round-trip error < 1e-12; degenerate-normal handling tested | 1 | correctness |
| 6 | Curve kernel v1 | `FFGeometry`: Bézier + NURBS evaluation, derivatives, Gauss–Legendre arc length, split, join, closest point, 2-D transforms | CI: 20 golden curves within 1e-6 of analytic length; closest-point on 1 000 random samples within 1e-7 | 5 | correctness |
| 7 | Mesh kernel v1 | Indexed triangle mesh, half-edge adjacency, normals, welding, manifold/watertight/orientation predicates, AABB tree, ray casting | CI: 25 mesh fixtures classified correctly; BVH ray hits match brute force across 10 000 rays | 5 | correctness |
| 8 | Tessellation pipeline | Chordal + angular tessellator, display and export LOD, triangle budget manager, deviation measurement | CI: tessellating a 20 mm-diameter circle at 0.005 mm chordal yields exactly ceil(pi / acos(1 - 0.005/10)) = 100 segments, and the maximum deviation at 20 sampled arcs is < 0.005 mm | 6, 7 | correctness |
| 9 | Metal-backed viewport bootstrap | `FFRender` projection/camera stack, `MTKView` host in SwiftUI, resize handling, sRGB output, MSAA 4x, FPS overlay | CI: Grid + axes draw at 60 fps in the simulator; Metal validation layer reports zero errors | 4, 7 | correctness |
| 10 | Camera and navigation | Orbit/pan/zoom (touch, trackpad, Pencil), orthographic/perspective, focus/frame, cursor-anchored zoom, named views | CI: Camera unit tests pass; UI test orbits and zooms then asserts camera state; zoom stays anchored within 1 px of the cursor | 9 | design |
| 11 | Units, grid, world space | Millimetre model, display units (mm, in, US size), 1 mm grid, world origin, scale bar, `RingSize` type | CI: Conversion tests (mm↔in↔US size) pass to 1e-6; grid snap at 0.1/0.5/1 mm; scale bar legible at 4 zoom levels | 10 | spec |
| 12 | Document model v0 and undo | `FFDocument`: Codable scene tree (nodes, transforms, curves, meshes, material refs), atomic save stub, command stack with coalescing and 100-step cap | CI: Save/load round-trip equality on 3 fixtures; 100 random edits undo then redo to an identical state hash | 11 | correctness |

### Arc 2 — Viewport and interaction (phases 13–24)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 13 | Real rendering of kernel meshes | RealityKit scene host, `LowLevelMesh` feed, PBR-lite shading, selection outline pass, ground shadow, `ViewportRendering` protocol | CI: A 100k-triangle mesh renders with shading; screenshot test shows outline on selection; CPU submit < 8 ms | 9 | correctness |
| 14 | Picking | GPU ID-buffer picking, analytic fallback for curves, hover/drag states, pick filters (curve, solid, stone) | CI: 500 synthetic picks match expected object within 1 px; hidden objects are never picked; curves pick within 6 pt | 13 | correctness |
| 15 | Gumball transform | Move/rotate/scale gizmo, axis and plane constraints, numeric entry, pivot editing, snap increments | CI: UI test drags X handle 10 mm with 1 mm snap and asserts exactly 10 mm; single undo restores the prior transform | 14 | design |
| 16 | Snapping engine | Grid, endpoint, midpoint, centre, intersection, on-curve, perpendicular, tangent, vertex, angle snap; marker graphics | CI: 30 headless snap cases pass; markers appear within 40 ms of hover and survive zoom | 15 | correctness |
| 17 | Selection and visibility | Click, shift-click, marquee selection; isolate, hide/show, show all; selection sets panel | CI: UI tests cover multi-select, marquee and isolate; filtered selection excludes other object types | 14 | design |
| 18 | Display modes | Shaded, shaded+edges, clay, wireframe, technical; per-viewport mode chip; material override | CI: Snapshot render per mode; mode persists across save/reopen | 13 | design |
| 19 | Measurement tools | Distance, angle, radius, diameter, ring inner diameter; unit-aware labels; snapped measurement points | CI: Measurements within 0.01 mm of fixture truth; labels remain legible at 3 zoom levels | 16 | spec |
| 20 | Layers v1 | Layers with visibility, lock, colour, current-layer; assign and select by layer; layer panel | CI: Locked layers reject edits; hidden layers are unpickable; wireframe uses layer colour | 12, 17 | design |
| 21 | Performance instrumentation | Overlay with FPS, frame ms, draw calls, triangles, `os_proc_available_memory` headroom, `thermalState` | CI: the overlay toggles from the HUD and its triangle/draw-call counters equal the synthetic scene's known counts exactly; thermalState is a valid enum case and available memory is > 0 | 13 | correctness |
| 22 | Render snapshot harness | Deterministic offscreen render, perceptual-hash comparison, baseline manifest, review workflow | CI: six scene hashes are identical across three consecutive runs; a baseline change is rejected unless --update-baselines is passed and writes a diff artifact plus a git-tracked note | 13 | correctness |
| 23 | UI smoke suite | XCUITest: launch, create document, load fixture, orbit, select, undo, save, reopen, attach screenshots | CI: Suite green in CI under 8 minutes; every test leaves a screenshot attachment | 2, 12 | correctness |
| 24 | Touch interaction pass | Gesture arbitration (orbit vs selection), palm rejection, ProMotion pacing, snap haptics, 44 pt hit targets | CI: 100 synthetic touch/Pencil gesture sequences drive the arbitration state machine with zero unintended camera moves; a view-hierarchy audit fails on any control smaller than 44x44 pt; physical palm rejection is recorded in evidence/024.json | 19 | design |

### Arc 3 — Document, files and data (phases 25–38)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 25 | A real, versioned file format | `.ffp` document bundle spec (manifest JSON, binary geometry buffers, thumbnails, checksums), JSON schema, version field, compatibility policy | CI: Schema validation tests pass; unknown future fields are preserved on rewrite, not dropped | 12 | spec |
| 26 | Reliable save and load at scale | Atomic writer (temp file + rename), reader with checksum verification, 1 000-object fixture | CI: Three save/load cycles produce identical state hashes; a truncated file falls back to the last good save with a clear error | 25 | correctness |
| 27 | No work is ever lost | Autosave (30 s + on background), edit journal, crash-recovery prompt, recovery snapshot retention | CI: A simulated kill during an edit recovers within 5 s of the last edit; journal is pruned to 5 snapshots | 26 | correctness |
| 28 | In-app document browser | Recents grid with thumbnails, rename, duplicate, delete, search, Files app integration via `UIDocument` | CI: UI test creates, renames, duplicates and deletes a document; Files provider shows the same bundle | 26 | design |
| 29 | OBJ interchange | OBJ importer (v, vn, v, f, groups, MTL subset) and exporter with unit note in header | CI: Import fixture with 3 groups and 4 materials; exported mesh reimports with bounds matching to 1e-4 mm | 26 | spec |
| 30 | Units and precision policy | Documented precision rules, rounding/formatting utilities, unit-aware measurement strings, tolerance constants per subsystem | CI: 10 000 chained operations drift < 1e-6 mm; a formatting-table test proves every user-facing value is rounded to its subsystem precision (0.001 mm, 0.01 deg, 0.001 ct) and no string shows more digits than that | 11, 26 | spec |
| 31 | Layers v2 | Layer states (visible, locked, colour, print), layer sets, assign/select, import from document template | CI: State saves and reloads exactly; layer set switch preserves visibility of other sets | 20 | design |
| 32 | Object tree panel | Tree with rename, reorder, drag-nest into groups, search, type icons, multi-select sync with viewport | CI: UI test nests a solid into a group and reorders within it; search finds by name and type | 17 | design |
| 33 | Grouping and pivots | Group/ungroup, nested transforms, pivot editing with axis presets, transform inheritance display | CI: Group rotation moves children rigidly; edited pivot survives save/load and undo | 32 | correctness |
| 34 | Duplication and arrays | Duplicate, linear array (count, offset, direction), radial array (count, axis, total angle) with editable parameters | CI: A 12-item 360° radial array spaces items at exactly 30° ± 1e-9; array parameters remain editable after creation | 33 | spec |
| 35 | Materials data model | Per-face-group material assignment, metallic/roughness parameters, colour, alloy presets, material inspector | CI: Assigning a material to a face subset persists through export and reopen; changing a preset updates all linked faces | 34 | spec |
| 36 | Metadata inspector | Part number, SKU, description, workshop notes, stone summary count, manufacturing flags | CI: All fields round-trip through the file format; stone summary matches the stone list exactly | 35 | spec |
| 37 | Document templates | Four original templates (solitaire ring, plain band, pendant, signet) stored as `.ffp` documents | CI: Each template opens in < 2 s with an empty undo stack and no missing references; snapshot test per template | 28, 35 | design |
| 38 | Format evolution safety | v1→v2 migration harness, fuzz corpus of 10 000 mutated documents, migration report surfaced to the user | CI: Fuzzing produces zero crashes and zero silent data loss; every rejected document explains why | 27, 37 | correctness |

### Arc 4 — Curve and sketch modelling (phases 39–56)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 39 | Draw lines that behave | Line chain tool with snapping, live length/angle readout, closing detection, typed length entry | CI: 20 drawn chains match typed dimensions within 1e-6 mm; closing a chain to its start produces one closed curve | 16, 30 | design |
| 40 | Arc tools | 3-point arc, centre–start–end arc, tangent arc, arc from fillet preview | CI: All three constructions pass analytic tests (centre, radius, endpoints) on 15 cases | 39 | correctness |
| 41 | Primitive curves | Circle, ellipse, rectangle, rounded rectangle, regular polygon with parameter editing after creation | CI: Each primitive is editable by parameters; radius/diameter/side-count changes preserve position and plane | 40 | design |
| 42 | Freehand spline drawing | Pencil-drawn interpolated spline (Catmull-Rom sampled, fitted to NURBS), smoothing slider, simplify threshold | CI: Drawn curve passes within 0.2 mm of sample points at default smoothing; simplify preserves shape within 0.05 mm | 19, 40 | design |
| 43 | Control-point editing | Drag, insert, delete, weight, degree elevation, knot display, tangent handles | CI: 25 editing operations produce expected curve hashes; weight change is reflected in curvature comb | 42 | correctness |
| 44 | Curve cleanup operations | Trim, extend, split at point, join, reverse, close, remove duplicates | CI: Join of two tangent curves reports G1 and yields one curve; trim endpoints lie within 1e-7 mm of the cutter | 43 | correctness |
| 45 | Offset curves | 2-D/3-D offset with tolerance, corner handling (round/miter), self-intersection cleanup | CI: Offset of 20 fixtures preserves minimum distance within 0.001 mm; spike cleanup leaves no self-intersections | 44 | correctness |
| 46 | Curve fillet and chamfer | 2-D fillet with radius preview, chamfer distance, trim/keep options | CI: Fillet tangency error < 1e-6; radius larger than leg length is refused with a specific message, not a broken curve | 45 | correctness |
| 47 | Curve diagnostics | Curvature comb, inflection markers, G0/G1/G2 continuity readout between joined curves, min-radius report | CI: Comb scale matches analytic curvature on 10 fixtures; continuity labels agree with numeric tests | 46 | spec |
| 48 | Projection and intersection | Project curves to planes and surfaces, intersect curve with plane/surface, extract section curves | CI: Projection round-trip error < 1e-5 mm; section of a revolved ring body matches expected circle radius | 45 | correctness |
| 49 | Profile library | Twelve original ring cross-sections (D-shape, flat, comfort-fit, knife-edge, cathedral variants) as editable curves | CI: Each profile opens as a valid closed curve; sweep preview works with every profile | 41, 48 | spec |
| 50 | Sketch plane tool | Define work plane from face, axis or three points; lock sketch mode; exit with commit/cancel | CI: Sketching on a tilted face produces curves in that plane; cancelling removes all sketch geometry in one undo | 49 | design |
| 51 | Constraint solver v1 | Horizontal, vertical, tangent, equal-length constraints, solver loop with residual display | CI: 15 constraint fixtures converge in < 10 iterations; over-constrained cases report which constraint conflicts | 50 | correctness |
| 52 | Constraint solver v2 | Coincident, perpendicular, parallel, concentric, dimensional (distance, radius, angle) constraints | CI: Solver passes 40 fixtures including two-dimensional constraint chains; edits respect all constraints | 51 | correctness |
| 53 | Driving dimensions | Dimension annotations that edit geometry, lock/unlock, unit-aware display | CI: Editing a dimension updates geometry to within 1e-6 of the typed value; locked dimensions survive accidental drags | 52 | design |
| 54 | Profile to surface preview | Live extrude/revolve preview from an open or closed profile without committing a solid | CI: preview updates on every drag event in an XCUITest; a CPU benchmark on a 200-point profile stays under 16 ms per update on the runner | 53 | design |
| 55 | Curve library | Save, name, tag and insert curves; drag-and-drop into the viewport; user library location inside the document container | CI: Inserted curve matches saved geometry exactly; library survives app restart | 49 | design |
| 56 | Curve performance pass | Spatial indexing for curve picking, incremental tessellation, benchmark harness with 10 000-point curves | CI: 10 000-point curve edits stay at 60 fps; picking under 2 ms; benchmarks committed with thresholds | 48 | concision |

### Arc 5 — Solid modelling (phases 57–78)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 57 | Extrude solids | Extrude closed/open profiles with caps, draft angle, direction, symmetric mode | CI: Volume of a 10×10×5 mm extrusion equals 500 mm³ ± 0.001; draft angle verified on section | 8, 54 | correctness |
| 58 | Revolve solids | Revolve profile around axis with angle, cap, direction; ring body primitive | CI: Revolved torus matches analytic volume within 0.5 %; 360° revolve is watertight | 57 | correctness |
| 59 | Sweep along rail | Sweep profile along rail with twist, scale, orientation modes, end caps | CI: Swept circle along a 50 mm rail has expected volume ± 1 %; self-intersecting rails are detected and refused | 58 | correctness |
| 60 | Loft | Multi-section loft (3+ profiles), closed/open, ruled vs smooth, end tangency | CI: Loft through three circles has the expected mid-section radius; surface normals continuous to 1e-3 | 59 | correctness |
| 61 | Solid primitives | Box, cylinder, sphere, torus, cone, tube with editable parameters and history entries | CI: Each primitive's volume matches analytic value within 0.1 %; parameters editable after creation | 35, 57 | correctness |
| 62 | Boolean union | Mesh CSG union with BVH broad phase, coplanar preprocessing, watertight output, exact-predicate fallback | CI: union of 50 fixture pairs is watertight and manifold; with A, B and A-intersect-B volumes precomputed in fixture JSON, abs(V(A union B) - (V(A) + V(B) - V(A intersect B))) <= 1e-4 * V(A union B) | 61 | correctness |
| 63 | Boolean subtract and intersect | Difference and intersection with preserved face groups, material inheritance, cut preview | CI: 50 fixture pairs pass volume and watertight checks; material of the base survives where faces remain | 62 | correctness |
| 64 | Boolean failure handling | Retry ladder (tolerance, jitter, nudge), explicit failure dialog with diagnostic, history entry kept re-runnable | CI: A 30-case adversarial corpus converges or reports a specific failure; zero silent invalid solids | 63 | correctness |
| 65 | Shell and hollow | Shell with wall thickness, inner offset, wall-thickness validation, drain-hole option stub | CI: Shell of a ring body keeps wall within 2 % of requested; too-thick requests are refused with the limiting region highlighted | 63 | correctness |
| 66 | Edge fillet and chamfer | Mesh fillet with radius feasibility, chamfer, variable radius per edge loop, fallback warnings | CI: Fillet radius error < 0.02 mm on 20 fixtures; infeasible radius reports the maximum feasible value | 65 | correctness |
| 67 | Hole and cut tools | Cylinder cut, counterbore, countersink, seat pocket, axis placement on faces | CI: Each cut's measured diameter/depth matches parameters within 0.01 mm; cuts remain editable | 64 | correctness |
| 68 | Solid validation and repair | Non-manifold detection, duplicate-face removal, orientation fix, hole filling, repair report | CI: Repairs 25 corrupted fixtures into watertight solids; every repair lists what changed | 64 | correctness |
| 69 | Manufacturing offset | Uniform and per-axis offset/shrink for casting allowance, preview in mm, apply as history step | CI: Offset of a 16.51 mm ring bore changes diameter by exactly 2×offset ± 0.001 mm | 68 | spec |
| 70 | Split and trim solids | Split by plane, by curve, by solid; keep/remove sides; trim with surface | CI: Split of a ring body by a plane yields two watertight halves whose volumes sum to the original ± 1e-6 | 68 | correctness |
| 71 | Mirror and pattern solids | Mirror with merge option, linear/radial solid patterns, merge-coplanar option | CI: Mirrored band is watertight after merge; radial pattern of 8 prongs lands at exactly 45° | 70 | spec |
| 72 | Mass properties | Volume, surface area, bounding box, centroid, metal weight per alloy using SG table, carat weight stub | CI: Computed volume of 20 fixtures within 0.1 % of analytic; 18K yellow weight matches hand calculation ± 0.001 g | 69 | correctness |
| 73 | Tessellation quality controls | Per-document chordal/angle tolerance, preview vs export quality, triangle count estimate | CI: Export mesh deviation measured < tolerance on 20 curved solids; changing quality does not change volume by more than 0.1 % | 72 | spec |
| 74 | Subdivision smoothing | Catmull-Clark subdivision with crease weights, smoothing preview, convert to solid | CI: Subdivided cube converges to expected limit volume; crease edges remain sharp within 1e-4 | 71 | correctness |
| 75 | Boolean performance | BVH refactor, parallel narrow phase, culling of interior triangles, benchmark suite | CI: A 200k-triangle boolean completes < 1.5 s on device class hardware; benchmark thresholds enforced in CI | 64 | concision |
| 76 | Feature tree evaluation | History graph with parameters, rebuild propagation, cache invalidation, failed-feature state | CI: Editing a base profile rebuilds 20 dependent features in < 300 ms; a failed feature keeps the last good mesh visible | 75 | correctness |
| 77 | Feature tree UI | Timeline with feature rows, edit/suppress/reorder/delete, error badges, preview on hover | CI: UI test edits a revolve angle and sees the model update; suppressed feature is skipped in rebuild | 76 | design |
| 78 | Kernel regression suite | 200 golden solid cases (JSON fixtures + expected volumes/hashes), CI job, tolerances documented | CI: all 200 cases are green in CI within 10 minutes; expected volumes come from fixture JSON rather than the kernel under test; hashes are regression-only and never substitute for a volume failure | 77 | correctness |

### Arc 6 — Gemstone geometry (phases 79–94)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 79 | Gemstone data model | Cut, dimensions, proportion set, material, colour, clarity, orientation, carat estimate; `Gemstone` value type | CI: Model round-trips through the document; invalid proportion combinations are rejected with a reason | 35 | spec |
| 80 | Round brilliant generator | Parametric 57/58-facet round brilliant from girdle diameter and proportion set; Tolkowsky (published 1919 ideal, not a current standard) and GIA-range presets | CI: Facet count = 57 or 58; table %, crown angle and pavilion angle measured from geometry match parameters within 0.05 % / 0.1° | 79 | correctness |
| 81 | Fancy cuts set 1 | Oval, pear, marquise generators with length:width ratio and bow-tie-aware proportions | CI: Each cut produces the expected facet count and L:W within 0.01; the mesh is watertight | 80 | correctness |
| 82 | Fancy cuts set 2 | Princess, emerald, cushion, trillion, baguette, heart generators | CI: Six cuts generate within 2 % of their reference volumes; girdle outline matches the named shape | 81 | correctness |
| 83 | Proportion editor | Live facet update from sliders (table, crown, pavilion, girdle, depth), constraint warnings, reset to preset | CI: Dragging any slider keeps the stone valid; extreme values clamp with a message instead of breaking geometry | 82 | design |
| 84 | Carat estimation | Coloured-stone `L×W×D×SG×factor` engine with per-cut coefficients, diamond fixed factors, girdle adjustment, ±5 % band shown; coefficients are trade formulas, not standards | CI: Estimates on 20 reference stones match published charts within 5 %; UI states the estimate is approximate | 83 | spec |
| 85 | Gem material presets | Diamond, moissanite, CZ, sapphire, ruby, emerald, topaz, amethyst, garnet, pearl with IOR, dispersion, SG, colour | CI: 10 presets validated (IOR 1.5–2.5, SG 2.6–4.0); carat estimate uses the correct SG per material | 84 | spec |
| 86 | Stone library | 50 generated stones across cuts/sizes, search, filter, favourites, drag-to-place | CI: Library loads in < 500 ms; every entry is generated (no external asset); search by size and cut returns correct sets | 85 | design |
| 87 | Melee library | 0.8–2.5 mm melee in standard gradations with carat weights (trade approximations), multi-select for pavé | CI: Selecting 50 melee stones inserts exactly 50 with correct carat totals ± 2 % | 86 | spec |
| 88 | Stone placement | Drop on surface, orient to surface normal, auto-seat, nudge along surface, replace on drop | CI: Placed stone sits normal to the surface within 0.5°; auto-seat produces a valid seat cut every time on 20 trials | 15, 87 | design |
| 89 | Multi-stone layout | Halo/pavé/channel arrays from the gem side, 0.15 mm Stuller vendor spacing default (configurable), collision report | CI: Arrays respect 0.15 mm spacing; collision report lists any overlapping pair with positions | 88 | correctness |
| 90 | Stone swap with re-seat | Replace a stone with a different cut/size, re-cut the seat, keep the setting or adapt it with rules | CI: Swapping 6 mm round → 8.5×6.5 oval re-seats and re-fits the head in one action, watertight result | 89 | correctness |
| 91 | Stone report | On-screen inventory, CSV and JSON export: count, cut, dimensions, carat estimate, material, position | CI: Report totals match the scene graph exactly; CSV opens with correct headers and units | 90 | spec |
| 92 | Gem interference validation | Girdle clearance, pavilion vs shank, prong contact coverage, culet clearance against the 0.5 mm rule | CI: 15 deliberately bad placements are all caught with specific messages; good placements produce zero findings | 91 | correctness |
| 93 | Gem display modes | Facet edges, wireframe, clay, material preview, selection highlight, per-stone label toggle | CI: Toggling each mode changes the render snapshot deterministically; labels never occlude the stone at default zoom | 88 | design |
| 94 | Stone library persistence | User library, custom stones saved to the document container, export/import library file | CI: Custom stone survives restart; exported library imports on a clean install with identical geometry hashes | 86 | spec |

### Arc 7 — Parametric ring builder (phases 95–114)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 95 | Ring sizing as a first-class model | `RingSize` data: US quarter sizes (trade convention), UK letters, EU/ISO circumference and JP as published tables (not one universal scale); conversion tables; inner-diameter source of truth | CI: 40 conversion fixtures match published tables within 0.02 mm; US 6 → 16.51 mm and ISO 51 → 16.23 mm exact | 30 | spec |
| 96 | Guided ring builder | Five-step wizard (size → profile → head → stones → finish) with persistent step editing and live preview | CI: Completing the wizard produces a ring document; re-entering any step and cancelling leaves the previous result intact | 77 | design |
| 97 | Shank profile engine | Width/thickness taper, outside profile (flat, half-round, knife-edge), inside profile (flat, comfort-fit), cathedral shoulders, bypass | CI: 12 profile presets (shank defaults are our inference, not standards) regenerate watertight; measured width/thickness at three stations match parameters within 0.05 mm | 96 | correctness |
| 98 | Ring resizer | Profile-aware resize from 3–13 US quarter sizes, keeps shank proportions and stone positions, warns on > 3-size jumps | CI: Size 6 → 9 changes bore to 18.95 mm ± 0.02 and keeps prong tips within 0.1 mm of design intent; 5-size jump warns | 97 | correctness |
| 99 | Head library v1 | Parametric 4-prong and 6-prong round heads, cathedral and peg variants, height/width parameters | CI: Each head regenerates watertight at 5 sizes; prong tips intersect the girdle plane within 0.05 mm | 79, 80, 97 | correctness |
| 100 | Prong generator | Prong count, diameter, taper, tip profile, seat height, spread angle, gallery rail attachment; 0.45 mm default is a Stuller vendor minimum, overridable | CI: the configured 0.45 mm Stuller default is enforced with a blocking warning that names the source; 100 generated prong sets contain no self-intersections | 99 | correctness |
| 101 | Stone seat cutting | Bearing cone, girdle support ledge, pavilion clearance, seat-depth validation against the 25 % Stuller vendor rule (overridable) | CI: Seat depth measured on section is within 0.01 mm of the configured value; stones placed in seats show ≥ 0.02 mm clearance | 80, 100 | correctness |
| 102 | Bezel setting | Full and partial bezel, wall thickness ≥ 0.45 mm (Stuller vendor minimum), height, inside relief, bright-cut edge option | CI: Bezel wall measured 0.45–1.2 mm; stone enters the bezel in a collision test with no interpenetration | 101 | correctness |
| 103 | Galleries and under-galleries | Gallery rails, decorative under-gallery, bridge supports, 0.4 mm rail-gap default (Stuller vendor rule) | CI: Gallery generation keeps the specified gap and stays watertight; missing support is flagged in the manufacturing check | 102 | correctness |
| 104 | Halo generator | Round/oval/cushion halos, melee count derivation, shared-prong rules, inner bezel or prong centre | CI: halo spacing is >= 0.15 mm on 10 fixtures (the 0.15-0.30 mm band is a trade convention with no published standard; only the lower bound is enforced); changing the centre stone size rebuilds the halo count correctly | 87, 103 | correctness |
| 105 | Pavé and bead layout | Placement along curves and on surfaces, spacing rules, bead size 0.4–0.5 mm (craft/vendor practice, not a standard), seat per stone, auto-prong | CI: 0.15 mm minimum stone-to-stone enforced; 200-stone pavé field all seats cut and no collisions in interference test | 87, 104 | correctness |
| 106 | Channel setting | Channel walls ≥ 0.4 mm (Stuller vendor rule), seat cutting, stone spacing, flat vs domed channel, end caps | CI: Channel cut width is 0.25–0.5 mm narrower than stones on 8 fixtures; stones sit below the wall edge by the specified amount | 105 | correctness |
| 107 | Tension setting (expert) | Tension-style ring with explicit structural warning, hardened-alloy preset, minimum cross-section validation | CI: The feature is unavailable unless the user accepts the risk dialog; minimum cross-section check blocks unsafe geometry | 106 | spec |
| 108 | Multi-stone assemblies | Two-stone, three-stone and side-stone layouts, shared shank, alignment rules, matching-height checks | CI: Three-stone layout keeps all tables coplanar within 0.05 mm; side stones never intersect the centre head | 107 | correctness |
| 109 | Parametric round-trip | Edit any builder step after the fact; size, profile, head, stone shape and stone size all re-fit without manual repair | CI: Size 6 → 9 and round 6 mm → oval 8.5×6.5 rebuild successfully in one action, watertight, with no leftover geometry | 80, 108 | correctness |
| 110 | Manufacturing checks for rings | Min wall, prong thickness, stone clearance, culet clearance, ring bore roundness, castability report per ring | CI: Report flags a deliberately thin 0.30 mm test wall (fixture, not a manufacturing minimum) and passes a 1.8 mm shank; each finding names the offending feature | 109 | correctness |
| 111 | Canonical workflow test | Automated end-to-end scenario mirroring the documented eight-step jeweller workflow, as an XCUITest plus geometry assertions | CI: Test completes in < 3 minutes in CI and ends with a watertight ring whose bore is 18.95 mm and whose stone is 8.5×6.5 mm | 110 | correctness |
| 112 | Ring presets | Ten original designs (solitaire, three-stone, halo, pavé band, signet, men's band, twist, bypass, vintage, eternity) | CI: Each preset opens, rebuilds and exports as watertight STL; snapshot per preset | 111 | design |
| 113 | Builder performance | Incremental rebuild of unaffected features, mesh caching, preview LOD during parameter drags | CI: check-evidence.sh 97 accepts a full-ring rebuild < 300 ms and drag preview < 16 ms on iPad Air (M3); a unit test proves an unchanged feature is not rebuilt | 112 | concision |
| 114 | Ring golden suite | 40 golden ring fixtures with expected volume, bore, stone positions and render hashes | CI: all 40 fixtures match expected volume, bore and stone positions from fixture JSON within 0.05 mm; hashes are regression-only | 113 | correctness |

### Arc 8 — Assemblies and libraries (phases 115–128)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 115 | Component architecture | Part library format, bundled parts (heads, shanks, settings), user parts directory, part metadata | CI: Bundled part opens, instantiates and exports; part format is versioned and schema-validated | 109 | spec |
| 116 | Instancing | Linked instances with one source of truth, instance overrides for material only, instance count display | CI: Editing the source updates all 20 instances in < 100 ms; override does not leak to the source | 115 | correctness |
| 117 | Part browser | Categories (rings, heads, settings, stones, findings), thumbnails, search, drag-to-canvas, favourites | CI: Browser opens in < 400 ms; drag inserts at the drop point; thumbnails render for every part | 116 | design |
| 118 | Component authoring | Convert selection to part, choose pivot and anchors, name/tag, save to user library | CI: Saved component reinstantiates with identical geometry hash; pivot and anchors persist | 117 | design |
| 119 | Anchors and attachment | Named anchors on parts (top, side, seat plane), snap-to-anchor with orientation, compatibility tags | CI: Dropping a head on a ring's seat anchor aligns within 0.01 mm and 0.1°; incompatible tags are refused | 118 | correctness |
| 120 | Mate-lite constraints | Align axis, concentric, tangency between anchors, offset and angle parameters | CI: 12 assembly fixtures satisfy constraints within tolerance; removing a mate restores freedom without moving parts | 119 | correctness |
| 121 | Assembly tree | Nested parts, overrides, visibility per node, selection sync, expand/collapse state persistence | CI: Assembly tree edits round-trip through save/load; per-node visibility does not affect siblings | 120 | design |
| 122 | Pattern tools | Pattern along curve, on surface, polar with orientation rules, spacing/count modes, merge option | CI: 24 stones along a 60 mm curve space at 2.5 mm ± 0.01; on-surface pattern keeps stones normal to the surface | 121 | correctness |
| 123 | Symmetry editing | Mirror assemblies, symmetry plane display, linked symmetric edits where safe | CI: Symmetric pair stays mirrored after 20 edits; breaking symmetry requires an explicit action | 122 | correctness |
| 124 | Exploded view | Explode distance, per-part direction, animation scrubbing, return to assembled state | CI: Explode/assemble restores exact transforms (hash equality); scrubbing is smooth at 60 fps | 121 | design |
| 125 | Assembly interference | Pairwise and assembly-wide collision checks with BVH, report list, highlight offending pairs | CI: Detects 20 planted interpenetrations and reports zero for 20 clean assemblies; check under 500 ms for 200 parts | 122 | correctness |
| 126 | Assembly mass report | Per-material totals, stone totals, total estimated weight, cost field stub | CI: Mass totals equal the sum of part masses ± 1e-6 g; report exports to CSV | 125 | spec |
| 127 | External part import | Import OBJ/STL as reference or solid, unit confirmation, cleanup, provenance tag | CI: Imported 50k-triangle mesh becomes watertight after repair and is tagged external in metadata | 125 | spec |
| 128 | Library backup and versioning | Library export/import bundle, version pinning per part, migration for part format changes | CI: Round-trip export/import preserves 100 parts with identical hashes; older part versions migrate or refuse cleanly | 126 | correctness |

### Arc 9 — Rendering and presentation (phases 129–146)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 129 | Physical material model | Metallic/roughness PBR parameters, IOR, clearcoat, normal strength; material editor with preview sphere | CI: Material edits persist and survive export; preview sphere matches the applied material's parameters exactly | 35, 93 | spec |
| 130 | Image-based lighting | Three original generated environments (studio, softbox, window) as HDRIs, intensity/rotation controls | CI: Environment rotation is continuous; no seams in the reflection; HDRI shipped inside the app bundle under 6 MB each | 129 | design |
| 131 | Alloy materials | 18K yellow/white/rose, 14K yellow/white/rose, platinum 950, palladium, sterling silver with measured albedo and roughness ranges | CI: the alloy table has 10 entries each with a source URL; gold base colour is within 0.02 of the cited Filament value (1.00, 0.85, 0.57); every swatch renders with all channels <= 1.0 | 130 | spec |
| 132 | Gem shader v1 | Fresnel, internal reflection approximation, facet-edge brightening, per-material IOR/dispersion parameters | CI: Diamond renders with visible brilliance and fire in a still; ruby and emerald show correct body colour under all three environments | 130 | correctness |
| 133 | Gem shader v2 | Screen-space refraction, dispersion by wavelength, sparkle modulation, performance budget | CI: check-evidence.sh 133 accepts the gem pass < 4 ms at 1080p on the baseline device; CI asserts no NaN/Inf pixels and identical sparkle output for two fixed frames | 132 | correctness |
| 134 | Lighting and shadows | Directional key light, area fill, rim light, contact shadows, shadow bias controls | CI: Shadow acne -free on a 0.1 mm feature at default bias; contact shadow follows object motion without lag | 131 | design |
| 135 | Ambient occlusion | SSAO with radius control, cavity shading for technical mode, AO in clay render | CI: ambient occlusion on versus off changes mean luminance inside the cavity fixture by >= 3 % and leaves vertex positions byte-identical | 134 | design |
| 136 | Studio presets | Five lighting/camera presets (catalogue, lifestyle, macro, flat-lay, dramatic), turntable rig | CI: each of the five presets renders a non-degenerate image (no NaN/Inf, > 1 % non-background pixels); device render time is recorded in evidence/136.json | 135 | design |
| 137 | Quality tiers and refinement | Draft/standard/high tiers, progressive sample accumulation, cancel and resume | CI: Draft shows a frame in < 300 ms; high-quality render refines until cancelled; resuming continues without restarting | 136 | concision |
| 138 | Offline high-resolution render | Offscreen renderer at 1×/2×/4× device scale, PNG and HEIC export, metadata embed | CI: 4× render of a 200k-triangle scene completes < 20 s; exported PNG has correct dimensions and colour profile | 137 | correctness |
| 139 | Backdrops and shadow catcher | Original backdrops (paper, stone, gradient), shadow-catcher floor, product-shot framing | CI: Backdrop change does not alter object materials; shadow catcher produces a grounded shadow in all presets | 138 | design |
| 140 | Material library | Save, name, tag, apply, copy/paste materials, per-face assignment retained | CI: Material applied to a subset survives render and reopen; copying a material does not copy geometry | 129 | design |
| 141 | Annotated renders | Overlay measurements, stone labels, dimensions, scale bar into the exported image with placement controls | CI: Overlay text is legible at 2× and never clipped; toggling annotations does not change the render hash of the scene itself | 139 | spec |
| 142 | Compare views | Side-by-side and slider compare of metal-only vs stones vs final; per-viewport material override | CI: Compare view renders both variants from the same camera exactly; slider position restores after rotation | 141 | design |
| 143 | Preview performance budget | Frame budget enforcement, resolution scaling, dynamic quality during interaction | CI: check-evidence.sh 143 accepts sustained 60 fps at 1 M triangles on iPad Pro; a synthetic 20 ms frame triggers resolution scaling and quality downgrade in a unit test | 137 | concision |
| 144 | Colour management | sRGB/P3 handling, tone mapping, white balance, consistent colour between viewport and export | CI: Rendered swatch and exported PNG differ by ΔE < 2 in a measured comparison; P3 screens do not oversaturate | 138 | correctness |
| 145 | Render determinism suite | Fixed-seed renderer, golden images with perceptual tolerance, CI job | CI: six golden renders are stable across three runs within the perceptual threshold; a material change flags exactly the expected images, verified against fixture hashes | 144 | correctness |
| 146 | Turntable video | `AVAssetWriter` export of a turntable, duration/fps/resolution controls, progress and cancel | CI: an 8-second 1080p turntable export completes and reports exactly 240 frames at 30 fps; wall-clock time is recorded in evidence/146.json | 143 | design |

### Arc 10 — Manufacturing output (phases 147–160)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 147 | Wall thickness analysis | Ray-cast min-wall per sample point, heat map overlay, threshold slider, report list of thin regions | CI: A 0.30 mm test wall is flagged red and a 1.0 mm wall green; measured thickness matches a calliper fixture within 0.02 mm | 72, 110 | correctness |
| 148 | Undercut and draft analysis | Casting pull-direction analysis, undercut heat map, draft angle report per face group | CI: 15 planted undercuts all detected; a clean ring reports zero; direction change updates in < 300 ms | 147 | correctness |
| 149 | Shrinkage compensation | Per-alloy linear shrink table (gold 1.2–1.5 %, silver 1.5–2.0 %, platinum 2.5–3.0 %; vendor/process guidance, not standards), uniform apply, per-axis override, calibration note | CI: Applying 1.5 % increases bore by 1.5 % ± 0.001 mm; the compensation is a reversible history step | 69, 148 | spec |
| 150 | Print mesh preparation | Watertight check, orientation normalisation, degenerate removal, self-intersection repair, repair log | CI: 25 corrupt fixtures become watertight with a log of changes; unrepaired cases fail with a specific reason | 68, 149 | correctness |
| 151 | Hollowing and drain holes | Hollow shell with 0.7 mm minimum wall, drain hole placement, interior cleanup | CI: Hollowed ring weighs within 5 % of the analytic estimate; holes are 1.0–2.0 mm and fully through the shell | 150 | correctness |
| 152 | STL export | Binary and ASCII STL, unit note, watertight assertion, triangle budget check | CI: Exported STL imports into two independent slicers with zero repair warnings; units explicitly mm | 150 | spec |
| 153 | 3MF export | 3MF with units, materials, colours, object names, per-part grouping | CI: A 3MF writer validation fixture round-trips units and colours; part names preserved | 152 | spec |
| 154 | OBJ export | OBJ + MTL with groups per part, material names, unit header | CI: Reimport into FacetForge yields identical bounds and group count; MTL opens in a third-party viewer | 152 | spec |
| 155 | Print validation report | PDF report: dimensions, volume, weight, wall minimums, undercut result, watertight status, checksum | CI: Report values match the geometry queries exactly; PDF renders on iPhone and iPad without clipping | 151 | spec |
| 156 | Resin print guidance | Orientation suggestion, support-hint regions (overhang angle), estimated print height, suction-risk note | CI: Suggestion reduces overhang area measurably versus the worst orientation on 10 fixtures | 151 | design |
| 157 | Casting tree suggestion | Simple sprue/runner layout proposal, button placement, per-tree part list | CI: Proposed tree connects every placed part with no intersections; the user can accept or discard | 156 | design |
| 158 | Unit and scale guardrails | mm-only export assertion, filename convention with unit tag, pre-export checklist, scale sanity warnings | CI: Exporting an object at 10× expected scale triggers a blocking confirmation; every export name includes `mm` | 152 | correctness |
| 159 | Manufacturer presets | Casting-house, resin-printer and CNC profiles with wall/prong minimums and shrinkage defaults | CI: Selecting a profile changes validation thresholds and the report header; presets are data-driven, not hard-coded | 155 | spec |
| 160 | Export regression suite | 30 export fixtures with hashes, watertight assertions, slicer-compatibility checks | CI: Suite green in CI; any export change that breaks a fixture fails with the offending triangle index | 159 | correctness |

### Arc 11 — iPad UX, Pencil and accessibility (phases 161–178)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 161 | Task-first tool palette | Contextual palette of at most 8 tools that changes with selection, floating and repositionable, thumb/Pencil reachability zones | CI: Every primary task is reachable in 2 taps from a fresh document; palette never covers the selected object | 112 | design |
| 162 | Radial and context menus | Long-press radial menu with adaptive tool sets, per-context commands, Pencil hover expansion | CI: Radial menu opens in < 100 ms; selecting a wedge performs the same action as the toolbar equivalent | 161 | design |
| 163 | Pencil-native input | Pressure/tilt shaping for sketch tools, double-tap tool swap, Apple Pencil Pro squeeze with `preferredSqueezeAction` respected | CI: 100 drawn strokes show pressure response without jitter; squeeze shows the palette only when the system preference allows | 42 | design |
| 164 | Hover previews | Tool ghost, snap-point preview, dimension preview before commit | CI: a hover/pencil-hover event shows the preview before commit and cancel leaves the document hash unchanged; hovering commits no geometry | 163 | design |
| 165 | Keyboard and command palette | Full shortcut map, fuzzy command palette, shortcut cheat sheet, external-keyboard focus system | CI: Every menu command is invokable from the palette; 30 shortcuts verified by UI test | 161 | design |
| 166 | Pointer and trackpad | Hover states, right-click menus, scroll-wheel zoom, two-finger pan, pointer shape per tool | CI: Trackpad navigation matches touch navigation; context menu appears at the pointer | 165 | design |
| 167 | Multitasking and iPhone companion | Multi-window per document, scene state restoration, iPhone read/edit-lite layout down to 390 pt, Files handoff | CI: Two windows edit different documents without state bleed; iPhone layout passes the 5-width snapshot suite | 4, 166 | design |
| 168 | Themes and motion | Light/dark/high-contrast themes, reduce-motion and reduce-transparency support, accent colour | CI: Theme switch live-updates every screen; reduced-motion setting disables all non-essential animation | 161 | design |
| 169 | VoiceOver and Dynamic Type | Labels, values, hints, traits and rotor actions on every control; Dynamic Type to XXXL without truncation | CI: an XCUITest audit finds zero unlabelled interactive elements; every label fits at Dynamic Type XXXL in a layout test; the manual VoiceOver script is recorded in evidence/169.json | 167 | design |
| 170 | Keyboard and switch access audit | Full Keyboard Access on every screen, Switch Control ordering, visible focus indicators | CI: every command has a key equivalent and a focus path (unit inventory = 100 %); a keyboard-only ring build is recorded in evidence/170.json | 169 | design |
| 171 | Onboarding | Interactive tour, sample project, five-minute first-ring walkthrough, skip and replay | CI: an XCUITest completes the sample ring tutorial in < 5 minutes; skip and replay never block the UI | 169 | design |
| 172 | In-context help | Tool help sheets, inline tips, jeweller glossary, searchable offline help index | CI: Every tool has a help entry; search returns the tool for 40 common queries | 171 | spec |
| 173 | Error and recovery UX | Recoverable dialogs, undo affordances, cancellable progress, destructive-action confirmation, error codes with fixes | CI: No error path loses user data; every dialog has a cancel and a stated consequence | 167 | design |
| 174 | Localisation infrastructure | String Catalog, pluralisation, RTL layout, English + Persian strings, pseudo-localisation test | CI: Pseudo-localisation reveals no clipped strings; RTL mirrors navigation and toolbars correctly | 167 | spec |
| 175 | Visual identity | Original app icon set, tool glyph family, launch screen, marketing screenshots from original renders only | CI: Icon legible at 1024 px and small sizes; no third-party marks anywhere in assets | 168 | design |
| 176 | State completeness | Empty states, loading skeletons, cancellable long-operation progress, offline and zero-stone states | CI: every screen has empty and error state snapshots; cancelling a long operation returns to idle within 500 ms in a unit test | 173 | design |
| 177 | Accessibility regression suite | Automated audit in CI, label inventory, Dynamic Type and contrast checks | CI: Suite blocks merges that remove a label or break contrast; runs under 5 minutes | 169 | correctness |
| 178 | Usability study | Five timed jeweller tasks, screen recordings, findings list, every P1 fixed | CI: check-evidence.sh 178 accepts a record with 4 participants x 5 tasks, timings and an empty P1 list | 177 | spec |

### Arc 12 — Performance, reliability and release (phases 179–200)

| # | Goal | Deliverables | Acceptance | Deps | Axis |
| --- | --- | --- | --- | --- | --- |
| 179 | Scene graph performance | Instancing, frustum and occlusion culling, batching, LOD switching, million-triangle scene | CI: check-evidence.sh 179 accepts 1 M triangles at 60 fps on iPad Pro and 30 fps on iPad Air with < 500 draw calls; culling and instancing counters pass in a unit test | 143 | concision |
| 180 | Memory discipline | Streaming meshes, texture compression, purgeable caches, memory guard, jetsam-safe behaviour | CI: check-evidence.sh 180 accepts peak resident < 2.5 GB at 1 M triangles and a 30-minute soak without jetsam; the memory-guard policy passes a unit test | 179 | concision |
| 181 | Thermal and battery | Thermal-state adaptive quality, frame cap at serious, battery profiling, idle suspension | CI: check-evidence.sh 181 accepts a 20-minute session below serious thermal state with battery drain recorded; the thermal policy selects the documented quality tier per state in a unit test | 180 | concision |
| 182 | Startup performance | Launch instrumentation, lazy module loading, precomputed caches, cold-start budget | CI: check-evidence.sh 182 accepts cold start < 2 s on iPad Air; a simulator launch smoke records timestamps and fails if the app is not interactive within 5 s | 179 | concision |
| 183 | Large document stress | 500-part assembly fixture, load/save/render benchmarks, editor responsiveness under load | CI: 500-part document opens < 8 s, orbits at 30 fps, saves < 3 s, no data loss | 180 | correctness |
| 184 | Document robustness | Fuzz harness for `.ffp` and imported files, crash-free session tests, defensive decoding | CI: 10 000 mutated documents produce zero crashes; every failure surfaces a recoverable message | 38, 183 | correctness |
| 185 | Diagnostics | Local log viewer, exportable diagnostics bundle (device, build, scene stats), no telemetry | CI: Bundle exports without personal data; log viewer filters by subsystem and phase | 184 | spec |
| 186 | Privacy and compliance | Privacy manifest, required-reason APIs, data-not-collected declaration, file-access strings | CI: App Store validation passes with zero privacy warnings; manifest lists every required API | 185 | spec |
| 187 | Data migration policy | Versioning policy, migration tests across v1→current, deprecation window | CI: three frozen schema fixtures (v1.0, v1.1, malformed) are committed; each valid fixture opens and the malformed one is refused with a specific error and no data loss | 184 | correctness |
| 188 | Backup and iCloud Drive | Document backup/restore, iCloud Drive container support (files, not a sync service), conflict-copy rules | CI: Restore reproduces identical hashes; a two-device conflict produces a copy, never a silent overwrite | 187 | spec |
| 189 | One-command verification | `scripts/verify.sh` covering format, build, unit, kernel, UI smoke, accessibility and plan checks | CI: Clean checkout verifies green in < 15 minutes locally; CI calls the same script | 177, 188 | concision |
| 190 | CI hardening | Job matrix (unit, kernel, UI, accessibility), flaky-test quarantine policy, cache tuning, timeouts, actionlint | CI: Ten consecutive green runs; no job exceeds 45 minutes; quarantined tests are tracked, not ignored | 189 | concision |
| 191 | Release configuration | Release settings, symbol handling, optimisation, app thinning, launch screen, versioning from tags | CI: Archive builds with zero warnings; dSYMs produced; version and build derive from git tags | 190 | correctness |
| 192 | TestFlight pipeline | Manually triggered archive/export workflow, signing secrets documented, internal group, release checklist | CI: check-workflow.sh validates the archive/export workflow; check-evidence.sh 192 accepts a record with the TestFlight upload run URL and a physical-iPad install | 191 | spec |
| 193 | Store presence | App Store metadata, original screenshots and preview copy, keywords, support URL, age rating, export compliance | CI: Submission packet complete; no competitor marks in any asset or keyword | 175, 192 | design |
| 194 | Legal review | Freedom-to-operate screen, trademark search for FacetForge, NOTICE/licenses screen, clean-room attestation, provenance audit | CI: check-evidence.sh 194 accepts the signed attestation; NOTICE is generated from the dependency graph and fails if any package is unlisted | 193 | spec |
| 195 | User guide | In-app help book, printable PDF guide, tutorial project files, release-notes template | CI: Guide covers every tool; a jeweller completes the canonical workflow using only the guide | 172, 193 | spec |
| 196 | Architecture handoff | Consolidated ADRs, module map, contributor guide, cache/CI documentation, known limitations | CI: A new contributor builds and ships a change using the docs alone | 189 | concision |
| 197 | Feature parity audit | Traceability matrix scored against dossier A §4; gap list with explicit decisions | CI: Every capability marked shipped, deferred or rejected with a reason; no unexplained gaps | 195 | spec |
| 198 | Full sign-off run | On-device and simulator verification, accessibility audit, performance report, manufacturing validation | CI: scripts/release-report.sh regenerates every Appendix A bar from CI results and evidence, and any missing or failing bar fails the phase | 197 | correctness |
| 199 | Release candidate freeze | Bug bash, P0/P1 burn-down, final regression, release notes, rollback plan | CI: Zero open P0/P1; release notes approved; rollback plan tested | 198 | correctness |
| 200 | v1.0 ship packet | Tagged release, App Store submission packet, TestFlight build, documentation bundle, post-launch checklist | CI: tag v1.0.0 matches the bundle version; scripts/check-release.sh validates the submission packet; check-evidence.sh 200 accepts App Store Connect acceptance and a TestFlight install | 199 | spec |
## 4. Feature traceability (MatrixGold capability → FacetForge phases)

| MatrixGold capability (dossier A §4) | FacetForge | Phases |
| --- | --- | --- |
| Parametric history / Dynamic Commands | Feature timeline with editable parameters | 25–38, 76–77 |
| Ring Rail + Profile Placer + Sweep | Ring builder rail + profile sweep | 95–98, 109 |
| Matching Band Rail | Not in v1.0 — deferred to v1.1 | — |
| Ring Resizer | Profile-aware resize | 98 |
| Head Builder | Parametric 4/6-prong heads | 99–100 |
| Prong Placer, Smart Prong, Prong Guides | Prong generator + guides + validation | 100, 110 |
| Gem Placer / Gem on Curve / Gem Springs | Stone placement + arrays | 88–90 |
| Halo, Bezel, Pave, Channel, Micro-Prong | Setting generators | 102–106 |
| Tension setting | Expert mode with structural warning | 107 |
| Custom Gem Builder / Scanned Gem Converter | Parametric gem generators (scanned import deferred) | 80–83, 127 |
| Gem Report / Metal Weights | Stone report + mass properties | 72, 91, 126 |
| Render Studio / Batch Render | Studio renderer + offline export | 129–146 |
| Animation Studio | Turntable video only; keyframe animation deferred to v1.1 | 146 |
| Tech Report | Print/validation PDF | 155 |
| STL / 3DM / OBJ export | STL/3MF/OBJ + 3DM read (3DM write deferred to v1.1) | 152–154 |
| Clayoo SubD/Emboss/Sculpt | Catmull-Clark smoothing + creases only; sculpt/emboss deferred to v1.1 | 74 |
| Bend / Twist / Shear / Polar Array | Polar/linear arrays only; bend/twist/shear deferred to v1.1 | 34, 71, 122 |
| Thickness Analysis / Bounding Box | Wall-thickness heat map + mass properties | 72, 147 |
| Project Manager / Job Bags | Document browser + templates | 28, 37 |
| Layers / Dynamic Groups | Layers + object tree + selection sets | 20, 31–32 |
| Command search | Command palette | 165 |

## 5. Appendix A — Quality bars (measured, not aspirational)

| Area | Bar | Enforced in |
| --- | --- | --- |
| Cold start | < 2 s to interactive on iPad Air (M3) | 182 |
| Viewport | 60 fps at 1 M triangles (iPad Pro), 30 fps (iPad Air) | 143, 179 |
| Ring rebuild | < 300 ms full, < 16 ms during parameter drag | 113 |
| Boolean | < 1.5 s for a 200k-triangle pair | 75 |
| Save / load | < 3 s for a 500-part document | 183 |
| Memory | < 2.5 GB peak resident at 1 M triangles | 180 |
| Export | Watertight STL/3MF at 0.005–0.01 mm chordal deviation | 152–153 |
| Accessibility | 100 % labelled controls, AA contrast, Dynamic Type to XXXL | 169, 177 |
| Legal | Zero vendor assets, marks or code; NOTICE complete | 194 |
| Gate | Every phase green before the next starts | Phase 0, all phases |

## 6. Appendix B — Risk register

| Risk | Likelihood | Impact | Mitigation | Phase |
| --- | --- | --- | --- | --- |
| Mesh booleans fail on real jewellery geometry | High | High | Retry ladder, repair, golden corpus, visible failures | 62–64, 78 |
| iPad memory limits on complex scenes | Medium | High | Streaming, LOD, purgeable caches, 8 GB floor testing | 180 |
| Simulator-only rendering hides device issues | High | Medium | On-device checkpoints at 143, 179, 181, 198 | 198 |
| Schedule drift across 200 phases | Medium | High | Phase-sized work, gate discipline, one phase per PR | all |
| Legal exposure from feature parity | Low–Medium | High | Clean-room protocol, no assets or marks, FTO screen | 194 |
| CI cost or time on macOS runners | Medium | Low | Single-simulator gate, SourcePackages cache, rerun discipline | 190 |
| Runner image or Xcode changes break CI | High | Medium | Pin image and Xcode, retry once, quarantine policy | 190 |
| Feature creep beyond parity | Medium | Medium | Deferred list, phase 197 audit | 197 |
| Context loss between phase agents | Medium | Medium | PROGRESS.md, ADRs, module contracts, tests as spec | 1–200 |

## 7. Appendix C — Phase checklist (copy into every PR)

```
Phase N — <goal>
[ ] branch phase-NN-<slug>
[ ] implementation and tests in the same commit set
[ ] swift format / lint clean
[ ] unit tests for new logic
[ ] acceptance check from MASTER-PLAN reproduced verbatim
[ ] UI smoke and screenshot if UI changed
[ ] accessibility labels on new controls
[ ] docs updated (PROGRESS.md, ADR if needed)
[ ] scripts/verify.sh green locally
[ ] GitHub Actions ios.yml green
[ ] no new warnings, no disabled tests, no TODO in shipping paths
[ ] cache-audit shows no growth outside .dev-cache
```

## 8. Appendix D — Glossary

| Term | Meaning here |
| --- | --- |
| Rail | Closed path curve a profile is swept along (ring circumference) |
| Profile | Cross-section curve of the shank |
| Head | The metal structure holding the centre stone |
| Seat / bearing | The conical ledge the stone's pavilion rests on |
| Girdle | Widest edge of a faceted stone |
| Melee | Small stones, typically under 2.5 mm |
| Pavé | Many small stones set with beads between them |
| Halo | Ring of melee around a centre stone |
| Gallery | Openwork structure under the head |
| Undercut | Geometry that cannot be pulled from a mould |
| Chordal deviation | Maximum distance between a tessellated mesh and the true surface |

---

**End of plan.** Exactly 200 numbered phases (1–200) plus the Phase 0 gate. Every phase ends
with the GitHub Actions build + test gate green; a red gate blocks the next phase. Nothing in
this plan requires vendor code, assets or documentation beyond the public sources in
`docs/research/`.
