# D — Core 3D/CAD functionality and kernel requirements

**Stream:** geometry engine, modelling operations, rendering, formats · **Researched:** 2026-11-06
**Labels:** FACT (cited) / INFERENCE (reasoning). No vendor code or binary was inspected.

---

## 1. What MatrixGold actually is, geometrically

| Claim | Reality | Label |
| --- | --- | --- |
| "Built on Rhino" | It is a Rhino 8 plug-in; a Rhino licence is required; it inherits Rhino's NURBS kernel wholesale | FACT |
| Surfaces | Every surface command yields a **NURBS** surface; trimmed surface = surface + 2-D trim curves in parameter space; joined faces = polysurface; closed polysurface = "solid" | FACT |
| SubD | Catmull-Clark control cage + limit surface, creases/holes, converts to NURBS or mesh; Clayoo bundled for SubD/Emboss/Sculpt | FACT |
| Booleans | Tolerance-parameterised, orientation-sensitive, may need `PrepareForBooleans`, can return null | FACT |
| Boolean failures are real | MatrixGold ships a **Nudge** toggle that "try[s] shifting and scaling geometry when boolean operations fail" | FACT |
| Fillet/chamfer | Surface operations: ruled/blend surfaces from rails, then trim and join | FACT |
| Loft | Fits through profiles with Loose/Normal/Tight/Straight styles + end tangency | FACT |
| Revolve | Exact rational surface with fully-multiple knots at quadrants, or rebuilt degree-3 | FACT |
| Gems | Custom Gem Builder defines shape "from table to culet"; scanned-gem conversion; prongs can be parametric or static | FACT |
| Render | Render Studio drives Rhino **Cycles** (CPU/GPU); iJewel3D is a separate WebGL/three.js viewer with custom gem refraction shaders | FACT |
| "Fully parametric" | Per-command history, breakable; Global Parametric off, pause-recalc, Nudge exist because rebuilds fail | INFERENCE |
| "Photoreal in seconds" | GPU Cycles or cloud iJewel, not live path tracing in the viewport | INFERENCE |

**Kernel takeaway:** the product is ~80 % Rhino's kernel and ~20 % jewelry parametrics. Our
clean-room app must own the 20 % and *replace* the 80 % with something it can actually ship on
an iPad: no NURBS B-rep library, no Rhino, no desktop CPU.

## 2. What a from-scratch iPadOS kernel has to provide

Ordered by dependency (this ordering is what MASTER-PLAN arcs 4–5 encode):

1. **Exact curve layer** — lines, arcs, circles, NURBS/Bézier evaluation, derivatives, arc
   length, split/join, offset, 2-D fillet, intersection with planes.
2. **Topology-aware mesh** — indexed vertices, half-edge adjacency, welded seams, manifold and
   watertight predicates, normals, BVH.
3. **Surface generators** — extrude, revolve, sweep (rail + profile, twist/scale), loft
   (multi-section), ruled, offset/shell.
4. **Booleans** — union/subtract/intersect on meshes with exact-ish predicates, coplanar
   handling, degenerate/tangent cases, and a **retry ladder** (re-tolerance → jitter → report).
   MatrixGold's Nudge threshold is evidence that no kernel gets this right first time; ours must
   *fail loudly* and offer repair instead of silently producing garbage.
5. **Fillets/chamfers** — mesh-based with radius feasibility checks, fallback to chamfer, and a
   visible warning when the requested radius exceeds local geometry.
6. **Tessellation control** — chordal deviation + angle + min/max edge length; separate display
   mesh and export mesh; casting export at 0.005–0.01 mm chordal.
7. **Gem generator** — parametric girdle curve + crown/pavilion facet planes by angle table +
   culet + girdle thickness; seat = revolved bearing cone + pavilion relief, booleaned with
   0.02–0.05 mm clearance.
8. **Formats** — 3DM read/write via openNURBS (note: reader/writer only, **no** booleans,
   intersections, meshing, SubD→Brep); STL and OBJ and 3MF for manufacturing; USDZ for
   AR/Quick Look (zipped USD package, JPEG/PNG/EXR/AVIF textures only).

## 3. Architecture decision: hybrid parametric → mesh solids

**Decision (INFERENCE, recorded as ADR-001 in the plan):** implement a **mesh-authoritative
solid kernel behind an exact parametric front end**, not a full NURBS B-rep.

- Exact layer: analytic + NURBS curves and *generated* surfaces (revolve/sweep/loft/extrude)
  that are always produced from parameters, never imported as arbitrary trimmed B-reps.
- Solid layer: watertight triangle mesh with half-edge topology; booleans, shell, fillets,
  seats, exports all operate here.
- History layer: every solid stores the feature graph that produced it; edits re-evaluate the
  exact layer and re-tessellate.

Why not true B-rep: robust trimmed-surface booleans (the Rhino/Parasolid class of problem) are
multi-year, and jewelry solids are dominated by revolve/sweep/loft forms with modest face counts.
At 0.005 mm chordal error a mesh is indistinguishable from the surface for casting and rendering.
Why not pure mesh: parametric rebuild and exact profiles (ring sizes, prong angles, facet angles)
need analytic definitions, or edits would accumulate error.

**Risk register for this choice**
| Risk | Mitigation | Phase |
| --- | --- | --- |
| Mesh booleans fail on coplanar/tangent geometry | Exact predicates, coplanar preprocessing, retry ladder, explicit failure UI | 62–64 |
| High triangle counts slow booleans | BVH broad phase, Metal compute narrow phase, LOD for display | 62, 179 |
| Parametric rebuild drift | Golden-mesh regression suite, tolerance-bounded comparisons | 78, 190 |
| Users expect STEP-class exchange | State supported formats in-app; 3DM read + STL/3MF/OBJ/USDZ write in v1 | 152–154, 186 |

## 4. Rendering requirements

- **Preview**: 60 fps at 1–2 M triangles on iPad Air (M3, 8 GB) — deferred or forward+ PBR,
  IBL, contact shadows, SSAO, MSAA 4×.
- **Materials**: metallic/roughness PBR with measured alloy albedo (18K yellow/white/rose,
  platinum, palladium, sterling), gem shader with refraction + dispersion approximation.
- **Offline render**: progressive accumulation on Metal compute; 2 s preview frame at 1080p is
  the budget; final render exports PNG/HEIC.
- **Determinism**: render snapshot tests with perceptual hash tolerance, not pixel equality.
- **Simulator caveat**: Simulator advertises roughly `MTLGPUFamily.apple2`, no programmable
  blending, no MSAA sampleCount 2, ≤64 KB constant buffers, ≤14 slots, private-only heaps, and
  **no meaningful performance measurement**. CI validates correctness only.

## 5. Geometry requirements per MatrixGold feature

| MatrixGold tool | Kernel primitive needed |
| --- | --- |
| Ring Rail | closed planar-ish rail curve; profile sweep |
| Profile Placer / Sweep | sweep with end caps and profile orientation rules |
| Ring Resizer | profile-aware radial reshape of a swept solid |
| Head Builder | revolved/revolved+cut head with prong pattern |
| Gem Placer / seat | boolean subtract of bearing cone + pavilion relief |
| Halo / Pavé / Channel | array placement on curve/surface + per-stone seat cuts |
| Bend / Twist / Shear | lattice deformation of mesh (and of feature params where analytic) |
| Thickness Analysis | signed distance / raycast min-wall query with heat map |
| Tech Report | mass properties, bbox, stone inventory, min-wall summary |
| STL out | watertight check, unit scale, binary STL writer |

## 6. Formats — hard facts and limits

- openNURBS is **MIT-style**: use/copy/modify/distribute/sublicense/sell, conditioned on
  including the copyright + permission notice; no express patent grant. McNeel states commercial
  use is encouraged.
- openNURBS does **not** provide booleans, intersections, meshing, or SubD→Brep conversion; it is
  a file I/O library. Any 3DM import must therefore be *converted* (mesh or curve-only) with a
  visible fidelity report.
- 3DM binary layout is undocumented beyond the source; do not hand-parse it.
- USDZ: zipped USD package, textures limited to JPEG/PNG/EXR/AVIF, no external references.
- 3MF carries units, materials and colours — the right default for print bureaus that reject STL.
- STL has no units; every export must state "mm" explicitly in the filename and report.

## 7. What we deliberately will not build in v1

- Arbitrary trimmed-NURBS B-rep booleans (out of scope, see ADR-001).
- STEP/IGES import-export.
- SubD sculpting brushes (Clayoo class). We support crease + Catmull-Clark smoothing only.
- Parametric feature exchange with Rhino beyond 3DM mesh/curve import.
- Cloud rendering.

## 8. Open questions

- How MatrixGold stores its own history inside .3dm (custom user data?) — unverified, and we do
  not need it: our document format is our own.
- iPadOS RealityKit `LowLevelMesh` throughput ceiling with per-frame edits — must be measured on
  hardware in phases 13–14 and 179.
- Exact float precision strategy for booleans on device: double-precision CPU kernel vs
  GPU float narrow phase.

## 9. Verification pass (2026-11-06)

A second public-source pass confirmed the kernel picture and corrected two details that matter to
our own design:

- **FACT — tolerance:** Rhino's default absolute tolerance is **0.01 mm** (units default to
  millimetres), not 0.001 mm. Section 3's 0.001 mm figure is our own modelling choice for jewelry
  work, not a Rhino default; the two must never be conflated in the plan or the UI.
- **FACT — no mesh→NURBS path:** Rhino documents no easy conversion from mesh to NURBS. A
  mesh-authoritative solid layer therefore cannot be “upgraded” later by a converter; any B-rep
  exchange would require a different kernel.
- **FACT — boolean failure causes:** open intersection loops from coincident seams,
  coplanar/near-tangent faces, invalid or non-manifold objects, or too-loose tolerance. Rhino
  leaves diagnostic text dots; MatrixGold adds a Nudge retry whose algorithm is undocumented.
- **FACT — history is breakable and conditional:** Rhino History links inputs to outputs, but
  booleans record only with `DeleteInput=No`; MatrixGold exposes an explicit Break History
  command. This is a per-command dependency graph, not a replayable global feature script.
- **FACT — SubD:** Rhino SubD is Catmull-Clark and convertible to NURBS or mesh; Clayoo is
  bundled with MatrixGold. MatrixGold's static surface prong explicitly targets meshes, surfaces
  and SubD objects.
- **INFERENCE:** the earlier architectural decision (exact parametric front end over mesh solids)
  is strengthened, not weakened: the host product's robustness comes from a mature B-rep kernel
  we are not licensing, and its own history model is per-command and breakable.

## Sources

- Rhino geometry types — https://www.rhino3d.com/en/docs/guides/modeling/rhino-geometry-types
- Reading SubD (openNURBS) — https://developer.rhino3d.com/guides/opennurbs/reading-subdivision-surfaces
- Rhino SubD — https://www.rhino3d.com/en/features/subd
- Revolve — https://docs.mcneel.com/rhino/8/help/en-us/commands/revolve.htm
- Loft — https://docs.mcneel.com/rhino/8/help/en-us/commands/loft.htm
- ChamferEdge — https://docs.mcneel.com/rhino/8/help/en-us/commands/chamferedge.htm
- BooleanDifference API — https://developer.rhino3d.com/api/rhinocommon/rhino.geometry.brep/createbooleandifference
- MeshingParameters — https://developer.rhino3d.com/api/rhinocommon/rhino.geometry.meshingparameters
- STL import/export — https://docs.mcneel.com/rhino/8/help/en-us/fileio/stereolithography_stl_import_export.htm
- File3dmSettings — https://developer.rhino3d.com/api/rhinocommon/rhino.fileio.file3dmsettings
- Rhino file formats — https://www.rhino3d.com/en/features/file-formats
- openNURBS overview — https://developer.rhino3d.com/guides/opennurbs/what-is-opennurbs
- USD for Apple devices — https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices
- 3.11 release notes (Nudge, Ring Rail degree 2) — https://en.design-engineering.net/matrixgold/matrixgold-3-11
- 2.5 release notes (Render Device) — https://en.design-engineering.net/matrixgold/matrixgold25
- MatrixGold 3.9 — https://blog.stuller.com/introducing-matrixgold-3-9-the-performance-update
- MatrixGold 3.10 — https://blog.stuller.com/introducing-matrixgold-3-10-the-efficiency-update
- MatrixGold 4.0 — https://blog.stuller.com/press-release/gemvision-releases-matrixgold-4-0
- iJewel3D docs — https://ijewel3d.com/docs/start/what-is-ijewel3d
- 3DM format description (LoC) — https://www.loc.gov/preservation/digital/formats/fdd/fdd000601.shtml
