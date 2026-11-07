# I — Competitive landscape and viable kernels

**Stream:** mission thread (f) — competitors, platform options, 3D kernels and licences ·
**Researched:** 2026-11-06
**Labels:** FACT (cited) / INFERENCE (our reasoning). Licence claims were taken from official
licence pages where possible. **This is research, not legal advice.**

---

## 1. Competitive map

| Product | Platform / UI paradigm | Price model | Jewelry emphasis | Label |
| --- | --- | --- | --- | --- |
| **MatrixGold** (Gemvision, a Stuller brand) | Rhino 8 plug-in, **Windows only**; viewport + command line + dockable panels; per-command parametric history | **$5,995** with Rhino 8, **$5,495** without; **$695/yr** membership; $2,995 transition for Matrix/RhinoGold owners | Gem/setting/ring builders, pavé, weight libraries, Render Studio, iJewel3D, direct casting output | FACT [1][2][3][4] |
| **Matrix / RhinoGold** (legacy) | Same Rhino lineage | Discontinued; support ended **31 Aug 2022**; no licence transfers | Still used in studios; frozen feature set | FACT [5] |
| **JewelCAD / JewelCAD Pro** | Windows only; fixed-menu legacy UI; vendor says it "will not be ported to any other operating system" | Dealer quote; hardlock dongle; network seats priced per seat | Uniform B-spline surface/block modelling, booleans with "super-subtractor", gem/setting library, STL/SLC, NC output, weight and stone count | FACT [6][7] |
| **3Design** (Type3 / Gravotech) | **Independent kernel**, not Rhino; Windows + macOS (Apple-silicon native); parametric construction tree | Quote-based, roughly $6k class; one retailer listed $6,255 | Custom stone builder, pavé/micro-setting, 3Shaper Sub-D module | FACT (snippets) [8] |
| **ZBrush** (Maxon) | Desktop Windows/macOS and **ZBrush for iPad**; brush/sculpt paradigm, no feature history | Subscription; desktop ~$399–479/yr, iPad via App Store (~$9.99/mo, $89.99/yr) | DynaMesh watertight volumes, IMM brushes for stone libraries, 3D Print Exporter; positioned as handcrafted, not engineering | FACT [9][10][11] |
| **Blender + JewelCraft** | Desktop only; add-on UI inside Blender | Free, **GPL** | Gems, prongs, cutters, gem-spacing checks, alloy weight, gem map, design report | FACT [12][13] |
| **Fusion** (Autodesk) | Windows/macOS desktop; timeline feature tree; mobile viewers | **$680/yr**; free personal use under revenue threshold | No jewelry-specific toolset; generic solid/surface/T-spline | FACT [14] |
| **Onshape** | Cloud, browser + **native iOS/iPadOS apps**; Part Studio feature list | Free public/non-commercial; Standard **$1,500**, Professional **$2,500**/user/yr | Generic MCAD; no gem/setting tooling — the closest existing iPad CAD UX benchmark | FACT [15] |

**INFERENCE — the opening.** The jewelry CAD market splits into four camps: Rhino plug-ins at
~$5–6k perpetual, legacy B-spline/CAM tools strong in Asian manufacturing, sculpting tools for
organic detail, and generic MCAD used because it is cheap. **No incumbent ships a native iPadOS
jewelry CAD *authoring* app.** The only iPad-native presences are ZBrush-for-iPad (sculpting) and
viewer/mobile apps (Onshape, Fusion). That is the product gap; it is also why "exactly like
MatrixGold" cannot mean "port the desktop ribbon".

**INFERENCE — price anchors.** A serious iPad app can sit well below $5,995 and still be
premium. The competing free/cheap options are generic or sculpting-first, not parametric jewelry
CAD. Do not compete on feature count with a 20-year Rhino plug-in; compete on the workflow the
jeweller repeats daily.

## 2. What the incumbents' paradigms imply

- MatrixGold assumes a mouse, a keyboard, a command line and four viewports. Its power is the
  parametric graph, not the ribbon.
- JewelCAD assumes a fixed menu and a dongle; its strength is manufacturing output and low
  training cost in factories.
- 3Design assumes a construction tree and a closed ecosystem; its strength is parametric
  stone/setting work without Rhino.
- ZBrush assumes a stylus, which is the one interaction model already proven on iPad.
- Onshape proves a native iPad CAD client is possible, but its interaction model is still a
  desktop feature tree shrunk onto glass.

**INFERENCE:** the winning iPad interaction is not a ribbon clone. It is task-first builders with
manipulable parameters in the viewport, Pencil for profiles and sculpt-like detailing, and a
feature timeline that a jeweller can read.

## 3. Kernel and library options — with real licences

| Component | What it gives | Licence (verified) | Can it ship in a closed-source App Store app? | Label |
| --- | --- | --- | --- | --- |
| **SceneKit** | Scene graph, some geometry | Apple framework | Yes, but **deprecated**; Apple directs new work to RealityKit | FACT [16] |
| **RealityKit** | PBR, meshes, USDZ, `LowLevelMesh`, custom Metal materials | Apple framework | Yes | FACT [17][18] |
| **Metal** | Compute, ray tracing, custom shaders | Apple framework | Yes | FACT [19] |
| **Model I/O** | Mesh import/export, voxels, subdivision, PBR materials | Apple framework | Yes | FACT [20] |
| **Assimp** | Many import formats | **BSD-3-Clause**; README explicitly allows static linking | **Yes**, with attribution | FACT [21] |
| **openNURBS** | 3DM read/write, NURBS evaluation | McNeel: "no restrictions… neither copyright nor copyleft" | **Yes** — but **no booleans, no tessellation, no intersection** | FACT [22] |
| **OpenCASCADE (OCCT)** | Full B-rep kernel, STEP/IGES, booleans | **LGPL-2.1-only + OCCT exception 1.0**; exception covers header inlining only | **Not safely.** OCCT's own docs warn that static linking or App Store distribution requires LGPL §6 relink rights → commercial licence needed | FACT [23][24][25] |
| **CGAL** | Robust computational geometry | Dual **GPLv3+ / LGPLv3+**; kernel+support LGPL, most algorithms GPL | **No** for GPL parts; LGPLv3's installation-information requirement is impractical on locked iPadOS. Commercial licence available | FACT [26] |
| **libigl** | Geometry processing | Core `include/igl` = **MPL-2.0**; `include/igl/copyleft/*` pulls GPL/AGPL (CGAL, tetgen) | **Yes if** copyleft headers are excluded; publish changes to MPL files | FACT [27][28] |
| **Manifold** | Guaranteed-manifold mesh booleans | **Apache-2.0** | **Yes** — static linking fine | FACT [29] |
| **OpenVDB** | Volumetric data, level sets | **Apache-2.0** | Yes, but heavy dependencies (TBB/Blosc) | FACT [30] |
| **Draco** | Mesh compression | **Apache-2.0** | Yes | FACT [31] |
| **OpenUSD** | Scene interchange | **Tomorrow Open Source Technology 1.0** (Apache-2.0 plus a trademark clause) | Yes, but large dependency graph | FACT [32] |

### App Store licensing facts

- **FACT** App Store Review Guideline 5.2 requires the developer to hold the rights to everything
  in the bundle. No guideline names GPL or LGPL explicitly. [33]
- **FACT** The Apple Developer Program License Agreement defines FOSS and imposes Apple's own
  distribution and DRM terms. [34]
- **INFERENCE** GPLv3's "no additional restrictions" is incompatible with App Store DRM; this is
  legal consensus, not an Apple statement. LGPL is unresolved in practice: static linking plus
  App Store distribution makes the §6 relink obligation hard to satisfy. Treat OCCT and CGAL as
  **licence-blocked until counsel or a commercial licence says otherwise.**

## 4. iPadOS runtime constraints that shape a kernel

- **FACT** iPadOS enforces a per-process resident-memory limit and kills apps that cross it
  (`per-process-limit` jetsam). The limit varies by device and Apple does not publish numbers. [35][36]
- **FACT** `os_proc_available_memory()` returns remaining headroom; Apple says treat it as
  advisory, do not cache it, and do not use it to maximize usage. [37]
- **FACT** `ProcessInfo.thermalState` escalates nominal → fair → serious → critical; Apple
  instructs reducing frame rate, LOD and deferred work at `serious`. [38]
- **INFERENCE** Budget roughly 300–600 MB of working set on 8 GB iPads. A 2 M-triangle model is
  ~56 MB of raw position/index data, but half-edge adjacency plus undo history typically
  multiplies that 4–6× (~250–350 MB). CAD-scale meshes need streamed evaluation, display/export
  LOD separation, and decimation above ~1–2 M triangles.

## 5. Research-level stack conclusion (not a phase plan)

- Render/scene: **RealityKit + Metal**, Model I/O for interchange. SceneKit is a dead end.
- Booleans: **Manifold** (Apache-2.0) is the strongest permissively licensed option; a
  from-scratch mesh kernel is also viable but must match its robustness or fail loudly.
- 3DM: **openNURBS** for read/write only; never expect it to boolean or tessellate.
- Geometry processing: **libigl MPL core** if needed; exclude `copyleft/`.
- Avoid: **OCCT** and **CGAL** without a commercial licence; **GPL** code (Blender/JewelCraft)
  in the shipping binary.
- Do not adopt a dependency just because it is permissive: binary size, thermal cost and
  App Store review surface all matter on iPad.

**Plan decision (v1.1):** v1 ships Apple frameworks only. Manifold, openNURBS and libigl remain
research options, not approved dependencies until ADR-007's provenance and licence gate is
satisfied; OCCT, CGAL and GPL/AGPL are blocked absent a commercial licence and counsel.

## 6. What this means for positioning and claims

- "Exactly like MatrixGold" is not a shippable claim: different platform, different kernel, and
  the name is a trademark. The honest claim is **"the same jewelry workflow, rebuilt for iPad"**.
- Parity should be measured behaviour-by-behaviour (ring rail → gem → head → profiles → resize →
  export), not by counting ribbon buttons.
- Price and distribution can be a genuine advantage: no Rhino licence, no Windows PC, no dongle.
- The moat is not the renderer; it is the parametric jewelry graph plus a trustworthy
  manufacturing handoff.

## 7. Open questions

- Whether a commercial OCCT licence is affordable and worth it for STEP/B-rep parity. Until then,
  B-rep exchange is out of scope.
- Whether App Store review will ask about Manifold/libigl attribution; prepare a licence page.
- Real thermal and jetsam behaviour on the oldest supported iPad; must be measured on hardware.
- Whether any incumbent plans an iPad app; none is announced in public sources reviewed.

## Sources

1. https://gemvision.com/matrixgold
2. https://www.stuller.com/services/custom-jewelry-design-services/3d-jewelry-design-software/matrix-and-rhinogold
3. https://lemondim.com/en/matrixgold
4. https://gemvision.com/store/matrixgold-4/with-rhinoceros
5. https://en.design-engineering.net/end-of-support-for-matrix-rhinogold
6. http://jewelcadpro.com/techsup.html
7. http://www.jewelcadpro.com/program/Jcad51_Specifications.htm
8. https://www.sierraconsultancy.com/cad-jewellery-software-3design
9. https://support.maxon.net/hc/en-us/articles/4716058124444-How-do-I-subscribe-to-ZBrush
10. https://www.cgchannel.com/2025/05/maxon-discontinues-zbrushcore-and-zbrushcoremini-but-new-freemium-edition-of-zbrush-coming-soon/
11. https://www.maxon.net/en/zbrush-jewelry
12. https://docs.blender.org/manual/en/4.5/getting_started/about/license.html
13. https://github.com/mrachinskiy/jewelcraft
14. https://www.autodesk.com/products/fusion-360/pricing
15. https://www.onshape.com/en/pricing
16. https://developer.apple.com/documentation/scenekit
17. https://developer.apple.com/documentation/realitykit
18. https://developer.apple.com/documentation/realitykit/scene-content-models-and-meshes
19. https://developer.apple.com/metal/
20. https://developer.apple.com/documentation/modelio
21. https://github.com/assimp/assimp/blob/master/LICENSE
22. https://developer.rhino3d.com/guides/opennurbs/what-is-opennurbs
23. https://occt3d.com/dev/doc/overview/html/occt_public_license.html
24. https://spdx.org/licenses/OCCT-exception-1.0.html
25. https://occt3d.com/dev/doc/overview/html/index.html
26. https://www.cgal.org/license.html
27. https://libigl.github.io/license/
28. https://www.mozilla.org/en-US/MPL/2.0/FAQ/
29. https://github.com/elalish/manifold/blob/master/LICENSE
30. https://github.com/AcademySoftwareFoundation/openvdb/blob/master/LICENSE
31. https://github.com/google/draco/blob/main/LICENSE
32. https://github.com/PixarAnimationStudios/OpenUSD/blob/dev/LICENSE.txt
33. https://developer.apple.com/app-store/review/guidelines
34. https://developer.apple.com/support/terms/apple-developer-program-license-agreement
35. https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports
36. https://developer.apple.com/documentation/metal/reducing-the-memory-footprint-of-metal-apps
37. https://developer.apple.com/documentation/os/os_proc_available_memory
38. https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious
