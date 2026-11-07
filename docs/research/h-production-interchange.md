# H — Production and data interchange

**Stream:** mission thread (e) — manufacturing, export, weight and BOM · **Researched:** 2026-11-06
**Labels:** FACT / VENDOR (one supplier's guidance, not a standard) / TRADE (industry rule of
thumb) / INFERENCE. No vendor files or assets were copied.

---

## 1. Interchange formats and what they actually carry

| Format | Content | Units | Manufacturing suitability | Label |
| --- | --- | --- | --- | --- |
| **STL** | Triangle soup, no colour, no attributes | **None** — must be stated out of band | De facto for casting; needs watertight mesh | FACT [1][2] |
| **3MF** | ZIP + XML, objects, materials, metadata, declared unit | **Declared** | Good for bureaus that reject STL; ISO/IEC 25422:2025 | FACT [3][4] |
| **OBJ** | Mesh + MTL sidecar | None | Rendering/interchange, not a casting contract | FACT [4] |
| **3DM** | Rhino NURBS, layers, materials, units | Declared | Master geometry, not a print mesh | FACT [5] |
| **SLC** | 2½D stacked contour polylines, slice spacing fixed at export | Implied by slices | Legacy stereolithography; orientation must be chosen before export | FACT [6][7] |
| **PLY / USD / STEP / IGES** | Rhino can export; not MatrixGold-documented | Varies | Out of MatrixGold's supported set | INFERENCE [5] |

- **FACT** STL has no mandatory unit field, and Rhino's exporter applies a mesh tolerance (maximum
  deviation) and can export open objects, warning when the mesh is not closed. [2]
- **FACT** 3DM's binary layout is undocumented beyond the openNURBS source; it is a reader/writer
  format, not a manufacturing mesh. [5]

## 2. What MatrixGold actually exports

- **FACT** Gemvision's FAQ advertises **STL, 3DM and OBJ** as MatrixGold outputs. Stuller's page
  says "any 3D file format needed" and direct submission to Stuller CAD/CAM. [8][9]
- **INFERENCE** Because MatrixGold 4 is a Rhino 8 plug-in, Rhino's other exporters are technically
  reachable, but Gemvision does not document or support 3MF, SLC, STEP or IGES as MatrixGold
  outputs. Do not claim them as MatrixGold parity.
- **FACT** Production data leaves as **documents, not only geometry**:
  - Tech Report PDF (3.4), with CSV export; metal weights added to CSV in 3.11; 4.0 rebuilt the
    report with editable metal weights in grams and dwt, customer info, finger size, notes and a
    dedicated gem-map page. [10][11][12][13]
  - Gem Report with total gem count and weight, plus TXT export. [10][12]
  - 4.0 adds 3D Gem Labels. [13]
- **FACT** 4.0 adds **Scoop** (hollowing to a user-defined wall thickness) and **Thickness
  Analysis**. [13][14]
- **INFERENCE** Neither feature validates manifoldness. Watertightness still needs a mesh check.
- **INFERENCE** No MatrixGold-native shrink scale, sprue/tree builder or 3MF metadata pipeline was
  found. Shrinkage, sprues and repair appear to be manual Rhino/trade steps.

## 3. What a caster requires

- **FACT** Casters require a fully manifold, watertight mesh, correct millimetre scale, no
  self-intersections and no unintended internal voids. Defects in the file are reproduced in
  metal. [15]
- **FACT** Rhino's watertight check is a sequence: Join → Weld (180°) → UnifyMeshNormals →
  `SelNakedMeshEdgePt`. [2]
- **VENDOR** Minimum walls differ by source: Morris & Watson specify ≥0.40 mm general,
  ≥0.50 mm on broad/flat areas, ≥0.90 mm if rubber-moulded, ≥0.125 mm edge radii, ≥0.20 mm
  internal gaps, and hole depth ≤ opening width (≤0.30 mm). Other casters publish 0.6–1.0 mm. [16]
- **INFERENCE** There is no industry-wide minimum wall. The app must ship an overridable
  "casting house profile", not one hard-coded number, and must name the source of each default.
- **FACT** Finishing removes 0.10–0.20 mm, so dimension-critical fits must be built oversize. [16]
- **FACT** Hollowing is a burnout and weight strategy: shell parts over ~3 mm, use ~0.7 mm walls,
  and add drain holes and vents. Trapped resin or investment causes defects. [17]
- **FACT** At least one caster rejects models with unintended hollows. [15]

## 4. Shrinkage and sprues

- **VENDOR** Allow ≥1 % for gold and silver alloys and ~2 % for platinum; critical fits (stone
  seats, finger holes) are most affected. Casters quote roughly 1–3 % final dimensional variation
  by alloy and geometry. [16][15]
- **FACT** Metallurgical shrinkage is 5–6 % **by volume** for Au/Ag alloys. It is fed by liquid
  metal through the sprue; CAD scaling does not eliminate it. [18]
- **FACT** Feed-sprue cross-section is roughly 70–150 % of the attachment, attached at the
  thickest section, filleted, and round in section. [18]
- **FACT** Printer/resin shrinkage is a separate effect (post-curing under 1 %). [17]
- **VENDOR** Sprue policy is contractual: one caster expects the designer to add bridging sprues
  (≥0.80 mm) for weak parts and to separate STLs per alloy/component; another adds supports and
  sprue preparation itself and asks designers not to add print supports. [16][15]
- **INFERENCE** The app should not silently add sprues. It should expose a sprue-planning step and
  state who is responsible, per selected caster profile.

## 5. Weight, stones and bill of materials

- **FACT** Metal weight = volume (mm³) × specific gravity ÷ 1000, in grams. Stuller publishes SG
  values: 14K yellow 13.07, 18K yellow 15.58, sterling 10.40, platinum 21.45, wax 1.00. [19]
- **FACT** MatrixGold lets users override SG for custom alloys. [11]
- **FACT** An estimate excludes sprue metal, porosity and finishing loss; casters price on actual
  finished weight. [15]
- **FACT** A stone BOM is the Gem Report: grouped by shape/size/material, total count, total
  carat, a gem map, and (4.0) 3D gem labels. [12][13]
- **INFERENCE** Carat figures come from the gem library. A custom cut therefore needs verified
  dimensions, or the report must say the carat is estimated.
- **INFERENCE** A credible BOM needs both a machine-readable CSV and a human PDF, because the
  bench and the caster read different artifacts.

## 6. Handoff checklist (assembled inference)

1. Millimetres, stated in the filename and the report.
2. Closed, manifold mesh; no self-intersections; no unintended voids.
3. Wall thickness per the selected caster and alloy.
4. Shrink allowance agreed for critical fits; nominal size kept in the document.
5. Sprue plan agreed (who adds it, where).
6. One STL per alloy/component; metal and karat named.
7. Finger size, stone list with millimetre sizes and setting style.
8. Tech Report / gem map PDF plus CSV.
9. Finishing stock called out where a fit is dimension-critical.

## 7. What competitors do differently

- **FACT** RhinoGold was also a Rhino plug-in. Its Report Tool calculated metal weights, gem
  quantities and sizes, and carat weight, and produced detailed tech reports and gem maps with STL
  export. It is discontinued; Stuller no longer offers it and Gemvision no longer supports it. [20][21]
- **FACT** JewelCAD's native format is `.jcd`. It outputs SLC and converts ASCII/binary STL from
  SLC, reports volume/mass and centre of gravity, counts round stones, and its exports are
  documented as "without Boolean data". [22]
- **FACT** A service bureau reports that JewelCAD STL often contains unbooleaned or erroneous
  parts and prefers native `.jcd` files. [23]
- **FACT** 3Design is an independent parametric modeler (not Rhino), available for Windows and
  macOS, importing/exporting 3DM, STL, OBJ, STEP and IGES; the Designer edition has no STL
  export. [24]

**INFERENCE:** the market norm is "geometry plus a report". Tools that export only a mesh push
quality problems downstream, which is why casters prefer native files from some products. A new
app can differentiate by exporting a mesh that is *proven* watertight, with the proof attached.

## 8. Implications for FacetForge

- Treat the document as the source of truth; STL/3MF/OBJ are derived artifacts.
- Run an explicit pre-export validation: closed, manifold, outward-oriented, no degenerate
  triangles, no zero-area faces, no unintended shells. Fail loudly with the offending faces.
- Always state units. Put `_mm` in exported filenames.
- Ship casting-house profiles with sourced minima and a visible "defaults are vendor guidance,
  not a standard" disclaimer.
- Compute weight from mesh volume × SG, with an SG override and a stated tolerance.
- Emit BOM CSV and a PDF report; include stone count, carat estimate, alloy, size and a gem map.
- Do not implement sprue generation silently, and do not invent a shrink constant per alloy
  without a source and a calibration note.
- 3MF is worth supporting because it carries units and metadata; SLC is legacy and can wait.

**Plan decision (v1.1):** STL and OBJ are the MatrixGold-documented parity set (phases 152 and
154); 3MF is an additional FacetForge output (phase 153), not parity; 3DM is deferred to v1.1;
SLC is out of v1 scope.

## 9. Open questions

- Whether MatrixGold 4 writes any metadata into STL/OBJ (it does not appear to).
- Exact caster acceptance rules used by Stuller's own CAD/CAM service — not public.
- Whether a 3MF export would be accepted by the casting houses our users actually use; needs
  interviews, not speculation.
- How to validate watertightness on device fast enough for a 1–2 M triangle model.

## Sources

1. https://www.loc.gov/preservation/digital/formats/fdd/fdd000506.shtml
2. https://docs.mcneel.com/rhino/8/help/en-us/fileio/stereolithography_stl_import_export.htm
3. https://www.3mf.io/
4. https://3mf.io/resources/faq
5. https://www.rhino3d.com/en/features/file-formats/
6. https://docs.mcneel.com/rhino/8mac/help/en-us/fileio/slice_slc_import_export.htm
7. https://www.cati.com/wp-content/uploads/2022/01/objet30-v3-user-guide-english.pdf
8. https://gemvision.com/matrixgold
9. https://www.stuller.com/services/custom-jewelry-design-services/3d-jewelry-design-software/matrixgold
10. https://en.design-engineering.net/matrixgold/matrixgold32
11. https://en.design-engineering.net/matrixgold/matrixgold24
12. https://en.design-engineering.net/matrixgold/matrixgold-3-11
13. https://www.stuller.com/benchjeweler/resources/bencharticles/view/introducing-matrixgold-4-0-design-smarter-create-faster
14. https://www.evotechpacific.com.au/matrixgold
15. https://apexjewelrycasting.com/policies-terms-conditions
16. https://www.morrisandwatson.com/casting/cad-design-guidelines
17. https://formlabs.com/white-papers/introduction-to-casting-for-3d-printed-jewelry-patterns
18. https://www.ganoksin.com/article/sprue-system-design
19. https://www.stuller.com/articles/view/where-to-find-gravity-of-materials
20. http://help.tdmsolutions.com/rhinogold/6.5/en/Introduction.html
21. https://www.stuller.com/rhinogold
22. http://www.jewelcadpro.com/program/Jcad51_Specifications.htm
23. https://www.thinkcoltd.jp/zokei_service/software.html
24. https://www.sierraconsultancy.com/cad-jewellery-software-3design
