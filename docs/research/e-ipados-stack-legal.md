# E — iPadOS implementation options and legal boundaries

**Stream:** platform stack, Pencil, windowing, memory, simulator limits, clean-room law
**Researched:** 2026-11-06 · **Labels:** FACT (cited) / INFERENCE (reasoning)

---

## 1. Rendering and scene framework

| Option | Verdict for this app | Evidence |
| --- | --- | --- |
| **SceneKit** | **No.** Deprecated across iPadOS 8.0–26.0, "soft-deprecated": no new capabilities, bug fixes unlikely, Apple directs migration to RealityKit | FACT [1][2] |
| **RealityKit** | **Yes for display.** ECS engine, SwiftUI integration, PBR out of the box, `LowLevelMesh` (iPadOS 18+) accepts a custom vertex format updated on CPU or by Metal compute; `MeshDescriptor` for static meshes | FACT [3][4] |
| **RealityKit as modeler** | **No.** No B-rep/NURBS, booleans, snapping or constraint solver; it is a renderer/ECS, not a kernel | INFERENCE |
| **Custom Metal** | **Yes, behind an abstraction.** Needed later for GPU picking/ID buffers, custom gem refraction passes, million-triangle instancing. `CAMetalLayer`/`MTKView` | INFERENCE |

**Chosen architecture (ADR-002):** SwiftUI chrome + RealityKit viewport + own kernel in
Swift, with a `ViewportRendering` protocol so a Metal renderer can replace RealityKit for the
studio/preview modes without touching the kernel or UI.

- Exact geometry stays in **double precision** in the kernel; tessellation happens on a
  background actor; only float display meshes reach `LowLevelMesh`.
- RealityKit gives culling, shadows, IBL, tonemapping; we do not rebuild those.

## 2. Apple Pencil

| Capability | Detail | Label |
| --- | --- | --- |
| Touch model | `UITouch` adds azimuth, altitude, force; must handle `estimatedPropertiesExpectingUpdates` and replace estimates in `touchesEstimatedPropertiesUpdated(_:)` | FACT [5] |
| Sample rate | Device reports up to 240 Hz; UIKit delivers ~60 Hz — use `coalescedTouches(for:)` for fidelity | FACT [5] |
| Hover | `UIHoverGestureRecognizer` with `zOffset` 0–1; iPadOS 16.1+, Pencil 2 | FACT [6] |
| Squeeze | **Apple Pencil Pro only**; SwiftUI `onPencilSqueeze`, UIKit `UIPencilInteraction`; respect `preferredSqueezeAction`; `hoverPose` anchors palettes | FACT [7] |
| Low latency | `UIUpdateLink` (iOS 18+) with `wantsLowLatencyEventDispatch` and `wantsImmediatePresentation`, built for pencil drawing; requires a minimal render path | FACT [8] |
| PencilKit | Stroke/ink canvas producing `PKDrawing`; owns its sample pipeline | FACT [9] |
| PencilKit for CAD | **Wrong tool** — it returns decorative strokes, not a controllable numeric stream; keep it for markup only | INFERENCE |

**Input rule (ADR-003):** raw `UITouch` + coalesced/predicted samples; discard predicted
samples when real touches arrive; Pencil pressure/tilt drives sketch-curve shaping, not geometry
accuracy (geometry always snaps to the numeric model).

## 3. Windowing and multitasking

- Adopt scenes, `UISceneSizeRestrictions` (min/max), `UITraitCollection`,
  `windowScene(_:didUpdateEffectiveGeometry:)`, and `isInteractivelyResizing`. FACT [10]
- iPadOS 26: users can always resize scenes when multitasking is on; `UIRequiresFullScreen` is
  deprecated, so **opting out of resizing is impossible**; scene lifecycle becomes mandatory in
  the next major release. Do not query window size mid-resize — render at the old target until
  resizing ends. FACT [11]
- INFERENCE: one scene per document, min window ~640 pt wide, reduce AA/LOD while
  `isInteractivelyResizing` is true.

## 4. Memory, jetsam, thermals

- iOS/iPadOS kill apps over a **device-specific, unpublished** memory limit; usage is
  `rpages × pageSize`; `os_proc_available_memory()` reports bytes remaining and must not be
  cached; mark caches `MTLPurgeableState.volatile`. FACT [12][13]
- `ProcessInfo.thermalState` ∈ nominal/fair/serious/critical; at `.serious` Apple advises
  stopping or deferring heavy work, 60→30 fps, lower LOD. FACT [14]
- Hardware: iPad Pro (M5) 12 GB (256/512 GB) or 16 GB (1–2 TB); iPad Air (M3) 8 GB. FACT [15][16]
- **Budget (INFERENCE):** design to ~2–3 GB resident, 8 GB Air as the floor; tile/stream large
  assemblies; treat Stage Manager with another app as elevated risk.

## 5. Metal in the Simulator (what CI can and cannot prove)

- Simulator translates Metal to the host Mac GPU and advertises roughly `MTLGPUFamily.apple2`:
  no programmable blending, no MSAA sampleCount 2, constant buffers ≤64 KB and ≤14 slots,
  private-only heaps, and **performance/memory cannot be measured**. Apple: do not design the
  renderer there. FACT [17]
- GitHub arm64 macOS runners have a real Apple-silicon GPU, so simulator rendering works, but it
  remains a translation layer. FACT [18]
- **CI rule:** simulator proves correctness (no crash, correct pixels within tolerance); device
  proves performance. Every perf phase must record a real-device measurement or be marked
  "unverified on device".

## 6. Legal boundary of a clean-room reimplementation

| Rule | Basis | Label |
| --- | --- | --- |
| Copyright protects **expression**, never ideas/procedures/systems/methods of operation | 17 U.S.C. §102(b) | FACT [19] |
| Reverse engineering to learn functional interfaces can be fair use, but **no code may be copied** into the product | *Sega v. Accolade*, *Connectix* | FACT [20] |
| EULA/ToS/NDA can override fair use; click-through licences have been enforced | *BnetD*; EFF FAQ | FACT [20] |
| Anti-circumvention (§1201) separately bars defeating protection | 17 U.S.C. §1201 | FACT [21] |
| "Copying" can include imitation of non-functional elements, not only verbatim code | EFF FAQ | FACT [20] |
| Trade dress: for unregistered dress the claimant must prove **non-functionality** — weak protection for CAD UI look-and-feel | 15 U.S.C. §1125(a)(3) | FACT [22] |
| Patents are independent of copyright; independent creation is **no defence** | patent law basics | FACT |
| openNURBS is MIT-style: use/modify/sublicense/sell, must ship the notice, no express patent grant | McNeel LICENSE | FACT [23][24] |

**Clean-room protocol for this project (ADR-004):**
1. Specification team reads only public docs, file-format specs, marketing pages, tutorials and
   behaviour observed *as a user*. No decompilation, no binary inspection, no EULA breach.
2. Implementation team works from this dossier and the MASTER-PLAN only; never from vendor
   binaries, assets or source.
3. **No vendor assets**: every gem, head, shank profile, icon, font, texture and HDRI is authored
   or generated by us. No scraped libraries.
4. **No trademarks in the product**: app name, icon, bundle id, screenshots and marketing must not
   use "MatrixGold", "Gemvision", "Stuller", "Rhino", "Clayoo" or their logos. Factual
   interoperability language ("imports .3dm") is nominative at most; comparative marketing is avoided.
5. **Provenance log**: `docs/legal/provenance.md` records where each dataset/number came from.
6. **Freedom-to-operate screen** before submission (patent search on jewelry CAD parametrics,
   boolean nudging, gem rendering). Not legal advice; a lawyer reviews before ship.
7. Attribution screen in-app listing openNURBS and every third-party licence.

## 7. Platform decisions recorded

| ADR | Decision |
| --- | --- |
| ADR-001 | Hybrid parametric → mesh-solid kernel (see dossier D) |
| ADR-002 | SwiftUI + RealityKit viewport behind a renderer protocol; Metal for studio mode |
| ADR-003 | Raw Pencil touch pipeline, no PencilKit for geometry input |
| ADR-004 | Clean-room protocol above; no vendor assets or marks |
| ADR-005 | iPadOS 26+ minimum; iPhone = read-only viewer + quick stone/ring edits later |
| ADR-006 | One scene per document; adaptive layout down to 640 pt; no fullscreen lock |

## 8. Open questions

- Exact per-app jetsam ceilings per device are unpublished; measure on hardware in phase 180.
- Whether `LowLevelMesh` sustains 60 fps with 1 M dynamic vertices on M5 — measure in phase 13.
- Patent landscape around parametric ring builders is unscreened until phase 194.

## Sources

[1] https://developer.apple.com/documentation/scenekit
[2] https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit
[3] https://developer.apple.com/documentation/realitykit/lowlevelmesh
[4] https://developer.apple.com/documentation/realitykit/meshdescriptor
[5] https://developer.apple.com/documentation/uikit/handling-input-from-apple-pencil
[6] https://developer.apple.com/documentation/uikit/adopting-hover-support-for-apple-pencil
[7] https://developer.apple.com/documentation/applepencil/handling-squeezes-from-apple-pencil
[8] https://developer.apple.com/documentation/uikit/uiupdatelink
[9] https://developer.apple.com/documentation/pencilkit
[10] https://developer.apple.com/documentation/uikit/multitasking-on-ipad-mac-and-apple-vision-pro
[11] https://developer.apple.com/documentation/metal/managing-your-metal-app-window-in-ipados
[12] https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports
[13] https://developer.apple.com/documentation/os/os_proc_available_memory
[14] https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property
[15] https://www.apple.com/ipad-pro/specs/
[16] https://support.apple.com/en-us/122242
[17] https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator
[18] https://github.com/actions/runner-images
[19] https://www.law.cornell.edu/uscode/text/17/102
[20] https://www.eff.org/issues/coders/reverse-engineering-faq
[21] https://www.law.cornell.edu/uscode/text/17/1201
[22] https://www.law.cornell.edu/uscode/text/15/1125
[23] https://github.com/mcneel/opennurbs/blob/8.x/LICENSE
[24] https://www.rhino3d.com/en/features/developer/opennurbs/
