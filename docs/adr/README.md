# Architecture Decision Records (ADR-001 … ADR-007)

Status of all seven: **accepted** for v1.0, dated 2026-11-06 (ADR-007 added in the
2026-11-06 reconciliation).
Each decision is traceable to a research dossier in `docs/research/`.

---

## ADR-001 — Hybrid parametric → mesh-solid kernel

**Context.** MatrixGold inherits Rhino's trimmed-NURBS B-rep kernel (dossier D). Reimplementing
robust trimmed-surface booleans is a multi-year effort; jewellery solids are dominated by
revolve/sweep/loft forms with modest face counts.

**Decision.** Keep exact analytic/NURBS definitions in a parametric layer, tessellate to a
topology-aware (half-edge) triangle mesh, and make that mesh authoritative for booleans, shell,
fillets, seats and export. Every solid retains its feature graph so edits re-evaluate exactly.

**Consequences.** Shippable booleans on iPadOS; mesh-quality and repair tooling become
first-class; STEP-class B-rep interchange is out of scope for v1. Rejected alternative: full
B-rep or licensing a desktop kernel (both incompatible with scope and clean-room constraints).

---

## ADR-002 — SwiftUI chrome + RealityKit viewport behind a renderer protocol

**Context.** SceneKit is deprecated (dossier E §1); RealityKit supplies ECS, PBR, IBL, shadows
and `LowLevelMesh`; raw Metal is still required for GPU picking and the studio renderer.

**Decision.** UI in SwiftUI. Viewport behind `ViewportRendering`, implemented first with
RealityKit and later by a Metal studio renderer. RealityKit documents PBR, IBL and meshes but no
gem refraction/dispersion, so the gem pass is a custom Metal shader, not a RealityKit material.
Exact geometry never leaves the kernel as
float; only tessellated display buffers cross the boundary.

**Consequences.** Fast path to a good-looking viewport without rebuilding culling/tonemapping;
a second renderer is a known cost, isolated by the protocol.

---

## ADR-003 — Raw Apple Pencil input, not PencilKit, for geometry

**Context.** PencilKit owns the sampling pipeline and returns ink strokes (dossier E §2).

**Decision.** Use `UITouch` coalesced and predicted samples with pressure, altitude and
azimuth. PencilKit is used only for markup/annotation. Predicted samples are discarded when
real touches arrive.

**Consequences.** Full control over curve fitting and snapping; we own smoothing and
prediction, and must test it on device.

---

## ADR-004 — Clean-room protocol and original assets

**Context.** Copyright protects expression but not function (17 U.S.C. §102(b)); EULA and
anti-circumvention law restrict reverse engineering (dossier E §6).

**Decision.** Specification comes only from public sources in `docs/research/`. No vendor
binary inspection, no decompilation, no copied assets, code, help text, icons or fonts. No
vendor marks in product, bundle id, screenshots or marketing. All gems, heads, profiles,
textures and HDRIs are generated or authored here. Provenance is logged in
`docs/legal/provenance.md`; the licence/NOTICE screen ships with the app.

**Consequences.** Slower parity on proprietary libraries (we generate our own), but a defensible
position. A freedom-to-operate patent screen is required before submission (phase 194).

---

## ADR-005 — iPadOS 26+ first, iPhone companion later

**Context.** The product is a precision modelling tool; iPad + Pencil + Stage Manager are the
working surface. The mission also asks for iOS.

**Decision.** iPadOS 26.0 is the primary target. iPhone support begins in phase 167 as a
read/edit-lite companion (open, inspect, tweak stone/ring parameters, export), not a full
modelling surface.

**Consequences.** Focused UX for the hard problem; iPhone stays honest about what it can do.

---

## ADR-006 — One scene per document, adaptive layout, no fullscreen lock

**Context.** iPadOS 26 allows users to resize any scene and deprecates `UIRequiresFullScreen`
(dossier E §3).

**Decision.** One `UIScene` per open document, multiple windows allowed, minimum layout width
640 pt on iPad (390 pt on iPhone), `UISceneSizeRestrictions` declared, and rendering reduced
during `isInteractivelyResizing`.

**Consequences.** Correct multitasking behaviour by construction; layout must be tested at every
breakpoint, which phases 4 and 167 enforce with snapshots.

---

## ADR-007 — Dependency and exchange licence gate

**Context.** The pass-2 research (dossier I) verified that OCCT is LGPL-2.1 plus an exception that
does not cover App Store static linking, and that CGAL is GPLv3/LGPLv3. Both would require a
commercial licence or counsel before shipping in a closed-source iPadOS app. GPL/AGPL code is
incompatible with App Store distribution.

**Decision.** v1 ships Apple frameworks only. Any third-party dependency must be permissive
(MIT, BSD, Apache-2.0 or MPL-2.0 core), recorded in `docs/legal/provenance.md` before use, and
listed in NOTICE. OCCT, CGAL and GPL/AGPL code are prohibited without a commercial licence and
counsel. 3DM read/write is deferred to v1.1 and would require an openNURBS licence review; no v1
phase depends on it. MatrixGold-documented parity is STL and OBJ; 3MF is our additional output,
not parity, and SLC is out of scope.

**Consequences.** No STEP/B-rep exchange in v1. The mesh-authoritative kernel (ADR-001) carries
all v1 geometry. A future B-rep path is a separate, licensed decision, not a phase detail.
