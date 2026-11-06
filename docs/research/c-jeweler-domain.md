# C — Jeweler domain model

**Stream:** ring/gem/setting/manufacturing facts · **Researched:** 2026-11-06
**Labels:** FACT (cited) / INFERENCE (reasoning). Numbers are design inputs, not legal advice;
each is attached to the phase that must encode it.

---

## 1. Ring sizing

**US scale (FACT):** inner diameter `d = 0.8128 × size + 11.63` mm; circumference
`C = 2.55 × size + 36.5` mm; 0.032 in step per full size; quarter sizes stocked.

| US size | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Inner Ø mm | 14.07 | 14.88 | 15.70 | 16.51 | 17.32 | 18.14 | 18.95 | 19.76 | 20.57 | 21.39 | 22.20 |
| Circ. mm | 44.2 | 46.8 | 49.3 | 51.9 | 54.4 | 57.0 | 59.5 | 62.1 | 64.6 | 67.2 | 69.7 |

**ISO 8653:2016 (FACT):** ring size is the inner **circumference in mm** (41–76 range), measured
on a 160 ±0.5 mm ring stick, diameter tolerance ±0.02 mm. Reference points: 41 → 13.05,
51 → 16.23, 61 → 19.42, 71 → 22.60, 76 → 24.19 mm diameter.

**Sizing stock (FACT):** 2.61 mm of shank length ≈ one full US size; Stuller tolerance ≈ ⅛ size.

**Design decisions:**
- Store **inner diameter in mm** as source of truth; derive US/EU/ISO labels. (INFERENCE)
- Model sizing as a **profile-aware reshape**, not uniform scale: wide shanks and comfort-fit
  interiors change fit; 2 mm of shank length per size is the working rule. (INFERENCE)

## 2. Shank profiles and minimums

| Item | Value | Label |
| --- | --- | --- |
| Taxonomy | straight, tapered, reverse-tapered, cathedral, split, euro-style | FACT |
| Outside profiles | flat, half-round, knife-edge, half-round edge | FACT |
| Inside profiles | flat "standard", comfort-fit | FACT |
| Stuller minimum shank | 1.5 mm wide × 1.7 mm thick (older guide); current guide shows 1.2 mm and 1.7 mm because finishing removes up to 0.2 mm | FACT |
| Working defaults (our presets) | 1.8–2.2 mm wide, 1.6–2.0 mm thick at base; ≥1.8 mm under a heavy head | INFERENCE |

## 3. Cuts and proportions

**Round brilliant (FACT):** 57/58 facets. GIA explicitly does **not** define one "ideal" set;
FacetWare input ranges: table 44–72 %, crown 20–41.5°, pavilion 37.2–43.8°, star 35–75 %,
lower-half 60–95 %, girdle 1.5–11 %.

**Tolkowsky (FACT, 1919):** table 53 %, crown 34.5°, pavilion 40.75°, total depth 59.3 %,
crown height 16.2 %, pavilion depth 43.1 %, knife-edge girdle.

**Fancy shapes (FACT: GIA issues no cut grade; INFERENCE: trade-target ranges)**

| Shape | Depth % | Table % | L:W |
| --- | --- | --- | --- |
| Oval | 60–63 | 56–60 | 1.37–1.55 |
| Pear | 60–63 | 56–60 | 1.55–1.70 |
| Marquise | 60–63 | 56–60 | 1.90–2.10 |
| Heart | 56–59 | 56–60 | 1.00–1.20 |
| Cushion | 67–70 | 59–63 | 1.00–1.04 |
| Radiant | 67–70 | 64–68 | 1.25–1.40 |
| Princess | 71–75 | 68–72 | 1.00–1.04 |
| Emerald | 66–69 | 61–65 | 1.35–1.50 |
| Asscher | 66–69 | 61–65 | 1.00–1.04 |

## 4. Carat estimation

**Coloured stones (FACT):** `ct = L × W × D × SG × factor`

| Cut | factor | Cut | factor |
| --- | --- | --- | --- |
| Round | 0.0018 | Marquise | 0.0016 |
| Oval | 0.0020 | Pear | 0.0018 |
| Emerald / rect. step | 0.0025 | Rect. cushion | 0.0022 |
| Rectangle | 0.0026 | Heart | 0.0021 |
| Square step | 0.0023 | Cabochon | 0.0027 |

Girdle adjustment (FACT): thin −1…−2 %, extra-thick +7…+10 %; pavilion bulge +3…+18 %.

**Diamonds (FACT, fixed factors):** round `Ø² × depth × 0.0061`; oval 0.0062; princess/square
0.0083; baguette 0.00915; heart 0.0059; pear 0.00575–0.00615; marquise 0.00565–0.00595;
emerald 0.0080–0.0106 by L:W.

INFERENCE: diamond factor ≈ SG 3.52 × 0.0018, so one parametric engine with per-shape yield
coefficients covers all shapes; surface the estimate as **±5 %** in the UI.

## 5. Settings and manufacturing minimums (Stuller CAD/CAM standards)

| Feature | Minimum / rule | Label |
| --- | --- | --- |
| Prong diameter | **0.45 mm** | FACT |
| Girdle overlap | 15 % of girdle (≈0.15 mm) | FACT |
| Seat depth | no deeper than **25 %** of prong | FACT |
| Stone-to-stone | 0.15 mm | FACT |
| Gallery-rail gap | 0.4 mm | FACT |
| Culet-to-finger clearance | ≥0.5 mm | FACT |
| Bezel wall | ≥0.45 mm | FACT |
| Channel wall | ≥0.4 mm | FACT |
| Beads (pavé) | 0.4–0.5 mm, ≥0.01 mm separation | FACT |
| Channel cut width | 0.25–0.5 mm narrower than stones | FACT |
| Stone gap | 0.1 mm flat channel, 0.2–0.4 mm domed | FACT |
| Model tolerance for booleans/seats | 0.001 mm model, 0.02–0.05 mm seat clearance | INFERENCE |

**Setting taxonomy:** prong, bezel, channel, pavé/bead, halo, tension, cathedral, flush.
Halo = bezel/prong ring reusing 0.4–0.45 mm walls (INFERENCE). Tension setting has no published
numeric standard; requires FEA + hardened alloy — ship it as an expert preset with a warning,
not a default (INFERENCE).

## 6. Melee and castability

- **Melee carats (FACT):** 1.0 mm ≈ 0.005 ct · 1.3 ≈ 0.011 · 1.5 ≈ 0.015 · 2.0 ≈ 0.04 · 3.0 ≈ 0.10.
- **Cast minimums (FACT):** 0.40 mm general wall, 0.50 mm broad/flat, 0.90 mm if rubber-moulded;
  internal gaps ≥0.20 mm; edge radius 0.125 mm. Formlabs: 0.5 mm walls/prongs, 0.7 mm hollow.
  Stuller: 0.5 mm design elements, 0.4 mm openings.

## 7. Metals

| Material | SG (g/cm³) | Linear shrink on solidification | Label |
| --- | --- | --- | --- |
| 24K gold | 19.36 | — | FACT |
| 18K yellow | 15.58 | 1.2–1.5 % | FACT |
| 18K white | 14.64 | 1.2–1.5 % | FACT |
| 18K rose | 15.18 | 1.2–1.5 % | FACT |
| 14K yellow | 13.07 | 1.2–1.5 % | FACT |
| 14K white | 12.61 | 1.2–1.5 % | FACT |
| 14K rose | 13.26 | 1.2–1.5 % | FACT |
| 10K yellow | 11.57 | 1.2–1.5 % | FACT |
| Platinum (pure) | 21.45 | 2.5–3.0 % | FACT |
| Pt/Co 950 | 20.80 | 2.5–3.0 % | FACT |
| Pt/Ir 900/100 | 21.54 | 2.5–3.0 % | FACT |
| Sterling silver | 10.40 | 1.5–2.0 % | FACT |
| Wax (printed) | 1.00 | — | FACT |

INFERENCE: model at nominal size and apply shrink compensation per alloy/process,
**calibrated against a cast test ring**; vendor figures vary and are not standards.

## 8. Data-model implications

```
RingSize        { usQuarterStep, innerDiameterMM, isoCircumferenceMM, standard }
ShankProfile    { kind, widthMM, thicknessMM, insideProfile, taperCurve }
Stone           { cut, lengthMM, widthMM, depthMM, proportions, material, caratEstimate }
Setting         { kind, prongCount, prongDiameterMM, seatDepth, orientation, clearances }
Assembly        { ringRail, profiles[], shank, heads[], stones[], decorations[] }
Manufacturing   { alloy, shrinkagePercent, minWallMM, process, checks[] }
```

Every number above becomes a **validated constant with a test**, not a magic number in a
generator (see MASTER-PLAN phases 72, 94, 148).

## 9. Open questions

- Exact ISO 8653 diameter tolerance per size band — only ±0.02 mm stated publicly.
- Tension-setting stress limits are alloy- and geometry-specific; no public formula found.
- Pavé bead rules are craft practice, not standards; vendor guidance varies (0.4 vs 0.5 mm).

## Sources

- ISO 8653:2016 — https://www.iso.org/standard/65408.html ; sample PDF https://cdn.standards.iteh.ai/samples/65408/
- Ring size — https://en.wikipedia.org/wiki/Ring_size
- Stuller ring sizing — https://www.stuller.com/articles/view/ring-sizing
- Jewelry basics (profiles) — https://bescojewelers.com/wp-content/uploads/Jewelry-Basics.pdf
- Anatomy of a ring — https://castinghouse.com/jewelry-manufacturing/diamonds-and-setting/anatomy-of-a-ring.html
- Stuller CAD/CAM production standards — https://assets.stullercloud.com/web/apps/images/kbpdfs/CADCAMProductionStandards.pdf
- Stuller design guidelines — https://stuller.scene7.com/is/content/Stuller/DAS/09b4e2e2-e12e-45f8-a2ed-a4f80104aa9f.pdf
- GIA round brilliant anatomy — https://www.gia.edu/diamond-cut/diamond-cut-anatomy-round-brilliant
- GIA FacetWare help — https://www.gia.edu/facetware-help
- GIA fancy-shape buying guide — https://4cs.gia.edu/en-us/blog/how-to-buy-a-quality-diamond/
- Fancy-shape ranges — https://www.diamondscreener.com/education/recommended-depth-table-and-length-width-ratio-for-fancy-shape-diamonds
- Gem weight estimation — https://plumbclub.com/how-to-estimate-gem-weight/
- Diamond weight formulas — https://blog.esslinger.com/stone-weight-estimation-formula
- Channel setting technique — https://www.stuller.com/articles/view/techniques-for-channel-setting
- Melee size guide — https://meleedirect.com/size-guide
- Casting design guidelines — https://morrisandwatson.com/casting/cad-design-guidelines
- Formlabs jewelry parameters — https://formlabs-media.formlabs.com/
- Material specific gravity — https://www.stuller.com/articles/view/where-to-find-gravity-of-materials
- Casting shrinkage — https://bluecast.info/blog/3d-jewelry-casting:-master-dimensional-accuracy-and-castable-resin-shrinkage
