# A — MatrixGold product surface

**Stream:** product/editions/modules/pricing · **Researched:** 2026-11-06 · **Method:** public web sources only
**Labels:** FACT = stated by the cited source. INFERENCE = my reasoning. Nothing here comes from a
MatrixGold binary, installer, decompilation or private material — this is the clean-room input set.

---

## 1. What the product is

| Item | Finding | Label |
| --- | --- | --- |
| Vendor | Gemvision, a Stuller company | FACT [1][2] |
| Category | Jewelry-specific 3D CAD, delivered as a **plugin inside Rhino** | FACT [1][3] |
| Host | Rhino 8 (Windows only); new purchases may ship Rhino 9 with Rhino 8 included | FACT [3] |
| Current version | **MatrixGold 4.1, released 10 Nov 2026** | FACT [4][5] |
| Editions | One product line, no Standard/Pro split found; SKUs differ by Rhino inclusion | INFERENCE [1][3] |
| OS | Windows 10/11 only, Intel/AMD x86 (not ARM); no macOS/iPad build | FACT [2] |

**Why this matters:** the entire product is a parametric layer on a desktop NURBS kernel
(Rhino). There is no mobile edition and no documented cloud geometry service — the iPad app
must own its kernel outright. See dossier D.

## 2. Versions (observed cadence)

| Version | Date | Label |
| --- | --- | --- |
| 4.1 | 2026-11-10 | FACT [5] |
| 4.0 | 2026-05-18 | FACT [5] |
| 3.11 | 2025-11-26 | FACT [5] |
| 3.10 | 2025-06-23 | FACT [5] |
| 3.9 | 2025-05-05 | FACT [5] |

INFERENCE: two releases a year, roughly. 4.0 introduced 12-hour offline licensing; 3.9 was a
performance update; 3.10 added scanned-gem conversion and prong guides. This tells us which
capabilities are considered baseline: editable history, gem/prong tooling, render output.

## 3. Price and licensing

| Item | USD | Label |
| --- | --- | --- |
| Perpetual licence **with** Rhino | $5,995 | FACT [6] |
| Perpetual licence **without** Rhino | $5,495 | FACT [6] |
| Upgrade from MG2/MG3 (no Rhino) | $695 | FACT [7] |
| Transition from Matrix / RhinoGold | $2,995 with Rhino / $2,495 without | FACT [8] (dealer sheet) |
| Membership (support + minor updates) | $695/yr per licence, auto-renew | FACT [9] |
| Student | $299 / 6 months, $399 / year | FACT [3] |
| Education lab | 30 seats, quote | FACT [3] |
| iJewel3D visualiser add-on | $0 / $200 / $600 / $1,500 per year | FACT [10] |

Licence mechanics: perpetual, online activation, one active machine, internet needed for
validation (4.0 adds 12-hour offline checkout). FACT [3][11]

INFERENCE: our product cannot compete on price directly against a $5,995 desktop licence; the
iPad app's value is mobility + instant parametric building, not seat-cost parity.

## 4. Tool inventory (the parity checklist)

Names below are as the vendor/dealer documentation uses them. This is the list Phase 200's
feature-parity audit is measured against.

**Ring / band construction — FACT [12]**
Ring Rail · Matching Band Rail · Bangle Rail · Cathedral · Bypass · Outside · Profile Placer ·
Profile Editor · Ring Resizer · Profile Sweep with end caps.

**Stone & setting — FACT [12][13]**
Head Builder · Gem Placer · Gem on Curve · Gem on Ring Rail · Gem Springs · Gem Guides ·
Halo · Bezel · Pave · Channel cutter · Micro-Prong cutter · Prong Placer · Smart Prong ·
Prong Guides · Add Prong · Azure Cutters · Scanned Gem Converter · Custom Gem Builder ·
Gem Creator · Proxy Gem · MSR Gems · Gem Label.

**Transform / utility — FACT [12]**
Bend · Shear · Twist · Polar Array · Pull to Rail · Radial Cage Edit · Mirror Cutter · Scoop ·
Duplicate · Curve on Object · Thickness Analysis · Bounding Box.

**Signet / award — FACT [14]**
Advanced Signet Ring · Award Ring Builder.

**Rendering — FACT [15][16]**
Render Studio (Rhino Cycles) · Animation Studio · Batch Render · iJewel3D cloud visualiser.

**Manufacturing — FACT [15]**
Tech Report · Gem Map / Gem Report · material list · Stuller CAD/CAM submission.

**Organic modelling — FACT [12]**
Clayoo (SubD/Emboss/Sculpt) bundled.

**Parametric system — FACT [12][13]**
Dynamic Commands (editable history tree), editable booleans/cutters, style sheets,
Content Manager/Collections, Project Manager/Job Bags, SmartTrack-style aids.

## 5. System requirements

Windows 10/11 · Intel 7th-gen / AMD 1st-gen quad-core, **not ARM** · 8 GB RAM · 4 GB VRAM
(RTX recommended) · 512 GB drive · 1920×1080 minimum · ~5 GB install · broadband for
install/validation · tablets unsupported. FACT [2]

## 6. File formats

| Direction | Formats | Label |
| --- | --- | --- |
| Export (official) | STL, 3DM, OBJ | FACT [1] |
| Import (legacy) | Matrix / RhinoGold .3dm | FACT [1] |
| Host-inherited | STEP, IGES, DXF, DWG, 3MF, SAT, USD via Rhino 8 | INFERENCE [17] |
| Renders | JPG / BMP / PNG; iJewel PNG / MP4 | FACT [12] |
| Reports | Tech Report PDF/CSV, Gem Map | FACT [15] |

## 7. What this means for FacetForge (scope decisions)

| MatrixGold capability | FacetForge decision | Phase anchor |
| --- | --- | --- |
| Parametric history tree | **Must** — core differentiator; build early | 25–38, 76–77 |
| Rail + profile ring building | **Must** — canonical workflow | 79–98 |
| Head/prong/bezel/halo/pave/channel generators | **Must**, parametric | 83–92 |
| Ring resizer | **Must** | 82 |
| Gem builder + libraries | **Must**, generated (no vendor data) | 99–114 |
| Editable booleans | **Must**, with visible failure/retry UX | 62–64 |
| SubD sculpting (Clayoo) | Later / optional — not core to ring CAD | 74 (crease/smooth only) |
| Rhino-host format breadth (STEP/IGES/DWG) | **Out of v1**; STL/3MF/OBJ/USDZ/3DM-read | 152–154 |
| Cycles-raytracer parity | Preview-quality PBR + offline render is enough for v1 | 129–146 |
| Cloud visualiser (iJewel3D) | **Out of scope** — local render only | — |
| Windows-only requirement | Turned into the product's advantage | Phase 0 |

## 8. Unverified / open

- Regional pricing and the $2,495 transition figure come from a dealer sheet; not independently confirmed.
- Whether MatrixGold 4.1 still requires a separate Rhino 8 licence per seat in all regions.
- No public API or scripting surface was found; scripts inside MatrixGold are INFERENCE from Rhino's RhinoScript/Python host.
- Tool naming drifts between vendor pages and dealers; treat the table in §4 as "best public list", not canonical.

## Sources

[1] https://gemvision.com/matrixgold
[2] https://gemvision.com/matrixgold/systemrequirements
[3] https://www.evotechpacific.com.au/matrixgold-new-licence
[4] https://gemvision.com/
[5] https://en.design-engineering.net/matrixgold/matrixgold-update-history
[6] https://www.evotechpacific.com.au/matrixgold-new-licence
[7] https://gemvision.com/store/matrixgold-4-upgrade/without-rhinoceros
[8] https://gemvision.com/onesheeters/matrixgold_transition_pricing_2023.pdf
[9] https://gemvision.com/legal/mg-membership-terms
[10] https://ijewel3d.com/pricing
[11] https://lemondim.com/en/matrixgold/
[12] https://en.design-engineering.net/matrixgold/matrixgold-3-11
[13] https://www.evotechpacific.com.au/matrixgold
[14] https://www.multistation.com/en/product/gemvision-3d-software-matrixgold
[15] https://www.stuller.com/services/custom-jewelry-design-services/3d-jewelry-design-software/matrixgold
[16] https://www.icreatia.es/producto/matrixgold
[17] https://www.rhino3d.com/features/file-formats/
