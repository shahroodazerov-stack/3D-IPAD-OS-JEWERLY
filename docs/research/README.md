# Research dossier — index

This folder is the clean-room evidence base for FacetForge, an iPadOS jewelry CAD app. It was
built from **publicly documented product material only**: vendor pages, release notes, public
manuals and tutorials, standards bodies, licence pages, forums and reviews. No vendor binary was
inspected, decompiled or run; no vendor text, icons, screenshots, materials, HDRIs or models were
copied.

Two research passes produced it:

- **Pass 1 (2026-11-06):** product, UX, jeweler domain, kernel, platform/legal and delivery.
- **Pass 2 (2026-11-06):** the six mission threads below. Three threads already had deep coverage
  and were verified; three were added (`g`, `h`, `i`).

Per-file labels: **FACT** (stated in a cited source), **VENDOR** (one supplier's guidance),
**TRADE** (industry rule of thumb), **USER REPORT** (single user, not documentation),
**INFERENCE** (our reasoning). Citation fetch status is recorded in
`docs/evidence/link-status.md`; regenerate it with `python scripts/check-links.py`.

## The six mission threads

| Thread | Topic | Canonical file | Status |
| --- | --- | --- | --- |
| (a) | UI/UX and interaction model — workspace, ribbon, viewport, selection, panels, workflow | [b-matrixgold-ux.md](b-matrixgold-ux.md) | Pass 1, verified in pass 2 |
| (b) | Core 3D modelling — solids, curves, booleans, history/parametric tree | [d-cad-kernel.md](d-cad-kernel.md) | Pass 1, verified in pass 2 |
| (c) | Jewelry-specific tooling — ring builders, shanks, prongs, heads, gems, sizing, pavé, milgrain | [c-jeweler-domain.md](c-jeweler-domain.md) and the tool inventory in [a-matrixgold-product.md](a-matrixgold-product.md) | Pass 1, verified in pass 2 |
| (d) | Rendering, materials and presets | [g-rendering-materials.md](g-rendering-materials.md) | **Added in pass 2** |
| (e) | Production and interchange — STL/3MF/OBJ, casting, weight, stone counts, BOM | [h-production-interchange.md](h-production-interchange.md) | **Added in pass 2** |
| (f) | Competitive and technical landscape — peers, kernels, licences | [i-competitive-kernels.md](i-competitive-kernels.md) | **Added in pass 2** |

## Supporting research

| File | What it covers |
| --- | --- |
| [a-matrixgold-product.md](a-matrixgold-product.md) | Product surface, versions, pricing, tool inventory, file formats |
| [e-ipados-stack-legal.md](e-ipados-stack-legal.md) | iPadOS frameworks, Pencil, multitasking, memory, legal boundary |
| [f-engineering-delivery.md](f-engineering-delivery.md) | Repository layout, CI gate, macOS runners, caching, cost |
| [00-findings-and-constraints.md](00-findings-and-constraints.md) | Consolidated findings, verified environment facts, plan constraints, and the "must not do" list |

## How to use this dossier

1. Read `00-findings-and-constraints.md` first; it is the only file that records what was
   *verified in this environment* versus what was read in a source.
2. Use the six thread files for feature behaviour and cited detail.
3. Treat every number labelled VENDOR or TRADE as an overridable default, never as a standard.
4. Do not treat this dossier as a plan. It contains no phase sequence; the plan is
   `docs/MASTER-PLAN.md`.
