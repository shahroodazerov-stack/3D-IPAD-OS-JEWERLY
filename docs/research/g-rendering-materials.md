# G — Rendering, materials and presentation

**Stream:** mission thread (d) — rendering, materials, presets · **Researched:** 2026-11-06
**Labels:** FACT (stated in a cited source) / USER REPORT (one user, not vendor documentation) /
INFERENCE (our reasoning). No vendor assets, HDRIs, materials or screenshots were copied.

---

## 1. What Render Studio actually is

- **FACT** Render Studio is a customised build of Rhino's **Cycles** engine, not a separate
  renderer. A third-party comparison describes MatrixGold as using "its own heavily modified and
  streamlined version of Cycles for Rhino", with CPU, CUDA and RTX device options. [1][2]
- **FACT** MatrixGold 2.5 removed its internal "Render Device" preference and now links directly
  to Rhino's **Cycles Settings**. Rendering configuration is therefore Rhino-document state, not
  MatrixGold state. [3]
- **FACT** Rhino's render document properties expose resolution presets, DPI, and four quality
  levels with these sample counts: Low 15, Draft 50, Good 500, Final 1500. They also expose
  bounce limits for diffuse, glossy, transmission, volume and transparency rays, transparent
  backgrounds (PNG/TGA/TIF) and render channels (RGBA, distance, normal, albedo). [4]
- **FACT** Observed production renders use pass counts in the 300–1500 range; a reseller's
  comparison reports those values. This is offline rendering, not a live viewport mode. [1]

**INFERENCE:** "photoreal in seconds" in marketing refers to GPU Cycles on a desktop GPU or to
the separate real-time iJewel3D visualiser. It is not evidence of a path tracer running at
interactive rates inside the modelling viewport.

## 2. Material system

- **FACT** Render Studio organises materials by category (Metals, Gems, and others), assigns them
  through layers (`Metal 01`, `Gem 01`, …), and offers **Render Styles** that bundle a look.
  User materials and user styles can be imported and exported. [2][5]
- **FACT** 3.1 added eight "Render Metals": white, yellow, rose and green gold, each in polished
  and matte variants. 3.2 added 22k yellow gold. [6][7]
- **FACT** Gem materials ship in four styles — Classic, Colorful, Modern, Studio Diamond — with
  HSL sliders and per-material maps. [7]
- **FACT** A custom material can carry a **specific gravity**, which feeds the weight calculation
  rather than the shading model. [5]
- **FACT (vendor caveat)** The 3.1 notes state that advanced render materials "cannot be edited"
  and "will not work with most functions outside of rendering". [7]
- **USER REPORT** A 2026 McNeel forum post says only 14k gold is editable in rendered metals and
  that its colour cannot be changed. This is one user's experience, not vendor documentation, and
  it conflicts with the documented 22k and coloured-gold additions. [8]

**INFERENCE:** the product's material presets are a curated library layered over a generic PBR
shader. The recurring complaint is not that the shader is weak but that the *preset* is locked.
Our presets must therefore be ordinary data (albedo, roughness, metallic, IOR, dispersion, SG)
with no read-only "studio" tier.

## 3. Presentation controls

- **FACT** Focal blur with a selectable focal point and aperture arrived in 2.4. [9]
- **FACT** Custom HDR maps can be assigned separately to **Lighting**, **Reflection** and
  **Backdrop**, and render styles bundle environments. [9][10]
- **FACT** Batch Render (2.4+) renders by Style, Files, Layers, Materials and Views; outputs
  JPG/BMP/PNG with optional alpha; can be aborted with Esc; auto-saves into the project or a
  shared render folder. [11][12]
- **FACT** Animation Studio animates a camera along a path with alignment modes (curve, reverse,
  perpendicular) and animation presets. [10]
- **FACT** A Render Safe Frame exists, so composition can be checked before a long render. [3]
- **FACT** Alpha-channel output lets metal and gems be composited in another application. [11]

## 4. iJewel3D — the real-time visualiser

- **FACT** iJewel3D is a **separate** WebGL renderer built on three.js/Threepipe, not part of the
  Cycles pipeline and not a path tracer. [13]
- **FACT** It provides PBR metals with tonemapping/LUT presets and a custom gemstone shader with
  ray-traced refraction and dispersion. Gem parameters include dispersion, absorption, refractive
  index (default 2.60), transmission, reflectivity, ray bounces (default 4–5, maximum 16), gamma,
  RGB boost, inclusions, and a per-gem HDRI with rotation offsets. Metal and gem environments can
  be separate HDRIs, and each gem shape needs its own material layer. [14]
- **FACT** BatchX is a **local** desktop application (Windows and Apple-silicon macOS), not a
  cloud service. A 2048×2048, 10-second turntable is claimed in "under 20 sec on a simple
  laptop". [15]
- **FACT** MatrixGold 3.11 added an iJewel3D panel that exports JPEG/PNG/Web snapshots and 360°
  video with selectable duration and resolution. [7][16]
- **FACT (vendor position)** Gemvision describes iJewel as "not a traditional rendering engine":
  it is a fast visualiser, while Render Studio is for full lighting and material workflows. [13]

## 5. Honest quality limits

- Gem appearance is dominated by three things: real facet geometry, the environment map, and ray
  bounces. Vendor FAQ material attributes flat or white diamonds mainly to the HDRI, not the
  shader. [14][15]
- No MatrixGold **cloud** rendering was found in any public source. Batch Render and BatchX are
  local. Treat "cloud render" claims as unverified.
- The 300–1500-pass figures imply minutes, not seconds, for final stills. The fast path is the
  separate real-time visualiser.

## 6. What iPadOS 26 provides for an equivalent

| Capability | API / fact | Label |
| --- | --- | --- |
| PBR materials | `PhysicallyBasedMaterial` covers base colour, roughness, metallic, normal, AO, specular, clearcoat, sheen, anisotropy, subsurface, emissive; "all material properties supported by USDZ" | FACT [17] |
| Offscreen high-res frames | `RealityRenderer` renders a RealityKit scene into Metal `MTLTexture` camera outputs with IBL and pre/post-render Metal actions | FACT [18] |
| Image-based lighting | `ImageBasedLightComponent` with intensity exponent; lightmaps and diffuse light probes for baked GI | FACT [19] |
| Compute and ray tracing | Metal compute passes; Metal ray tracing with acceleration structures (iPadOS 17+) | FACT [20][21] |
| Upscaling / denoising | MetalFX spatial and temporal upscalers; Metal 4 adds `MTL4FXTemporalScaler`, `MTL4FXTemporalDenoisedScaler`, `MTL4FXFrameInterpolator` | FACT [22][23] |
| Camera / depth of field | Perspective and orthographic cameras; RealityView `depthOfField` effect exists but is off by default "because of its computational cost" | FACT [24][25] |
| Distribution | USDZ / Quick Look; RealityKit uses the metallic PBR workflow only, one packed texture per material, two UV sets, no NURBS patches, and ignores lights authored in USD | FACT [26][27] |
| Simulator | Forwards Metal to the host GPU, advertises Apple-family-2-class features, no 2× MSAA, no programmable blending, ≤64 KB constant buffers, ≤14 buffers, no performance measurement | FACT [28] |

## 7. Gap analysis for a jewelry CAD on iPad

| MatrixGold capability | Achievable on iPad with Apple frameworks? | Research conclusion |
| --- | --- | --- |
| Editable PBR alloy presets | Yes — `PhysicallyBasedMaterial` parameters | Data-driven presets; no locked tier |
| Studio HDRI lighting | Yes — IBL component + custom environment maps | Ship our own generated/lawfully licensed HDRIs |
| Focal blur / DOF | Approximate — post-process effect, not physical aperture | Label as a look, not optics |
| Turntable / camera animation | Yes — animate camera, render offscreen frames | Export MP4/HEVC via AVFoundation |
| High-resolution stills | Yes — `RealityRenderer` to an offscreen texture | Progressive accumulation on Metal compute |
| Batch renders | Yes — background tasks + offscreen renderer | Must respect thermal state and jetsam |
| Gem refraction and dispersion | **No documented RealityKit shader** | Requires a custom Metal path tracer (refraction + spectral dispersion) or baked variants |
| Cloud rendering | Not part of MatrixGold | Out of scope unless a service is deliberately added |

**INFERENCE:** the hard rendering problem is not metals or lighting; it is believable diamond
"fire". RealityKit can render a gem-shaped mesh with a high-refraction-looking material, but it has
no documented per-stone refraction/dispersion model. A credible v1 either (a) ships a custom Metal
gem shader with single-scatter refraction and an approximate dispersion term, or (b) ships baked
gem appearance variants and is honest about it. A full spectral path tracer is a separate product
decision, not a phase detail.

**Plan decision (v1.1):** v1 takes option (a): a custom Metal gem pass with single-scatter
internal reflection and an approximate dispersion term (phases 132–133). No RealityKit gem
refraction or dispersion is claimed; RealityKit remains the PBR/IBL viewport and host.

## 8. Clean-room material rules

1. Derive alloy colour/roughness from published physical data or our own measurements; do not
   extract MatrixGold materials or HDRIs. Specific gravity values are physical facts and may be
   used with a source.
2. Gem IOR and dispersion are physical constants; use published values and cite them. Do not copy
   vendor shader code or parameter presets wholesale.
3. Label every preset as an approximation. A rendered image is not a certification of colour.
4. Keep HDRIs and textures out of the repo unless their licence is recorded in
   `docs/legal/provenance.md`.

## 9. Open questions

- Exact MatrixGold alloy preset list and whether 4.0 changed the gem styles — not publicly
  enumerated.
- Whether Render Studio exposes denoising in the MatrixGold wrapper or only through Rhino Cycles.
- Real device throughput for a custom Metal gem shader and for progressive accumulation on an
  M-series iPad; must be measured on hardware, never in the Simulator.
- Whether Apple's MetalFX denoiser is usable with a hand-written path tracer at acceptable quality.

## Sources

1. https://www.cadjewelleryskills.com/jewellery-tech-blog-topics/jewellery-learning-resources/rhino-cad-rendering-comparison-test-part-1
2. https://gemvision.com/matrixgold
3. https://en.design-engineering.net/matrixgold/matrixgold25
4. https://docs.mcneel.com/rhino/8/help/en-us/documentproperties/render.htm
5. http://docs.mcneel.com/rhino/8/help/en-us/options/rhino_render.htm
6. https://en.design-engineering.net/matrixgold/matrixgold31
7. https://en.design-engineering.net/matrixgold/matrixgold-3-11
8. https://discourse.mcneel.com/t/matrixgold-rendering/223157
9. https://en.design-engineering.net/matrixgold/matrixgold24
10. https://blog.stuller.com/details-on-matrixgolds-newest-software-update/
11. https://blog.stuller.com/matrixgold-improves-with-batch-render-feature
12. https://en.design-engineering.net/matrixgold/matrixgold23
13. https://ijewel3d.com/docs/start/what-is-ijewel3d.html
14. https://ijewel3d.com/docs/edit/playground/diamond-materials.html
15. https://ijewel3d.com/docs/edit/batchx/introduction.html
16. https://www.cad-cast.com/post/matrixgold-and-ijewel3d-integration
17. https://developer.apple.com/documentation/realitykit/physicallybasedmaterial
18. https://developer.apple.com/documentation/realitykit/realityrenderer
19. https://developer.apple.com/documentation/realitykit/imagebasedlightcomponent
20. https://developer.apple.com/documentation/metal/compute-passes
21. https://developer.apple.com/documentation/metal/ray-tracing-with-acceleration-structures
22. https://developer.apple.com/documentation/metalfx
23. https://developer.apple.com/documentation/metalfx/mtl4fxtemporalscaler
24. https://developer.apple.com/documentation/realitykit/perspectivecameracomponent
25. https://developer.apple.com/documentation/realitykit/realityviewrenderingeffects/depthoffield
26. https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices
27. https://developer.apple.com/documentation/arkit/previewing-a-model-with-ar-quick-look
28. https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator
