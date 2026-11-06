# Architecture Decision Records (ADR-001 … ADR-006)

Status of all six: **accepted** for v1.0, dated 2026-11-06.
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
RealityKit and later by a Metal studio renderer. Exact geometry never leaves the kernel as
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
