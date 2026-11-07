# B — MatrixGold UI/UX and modelling workflow

**Stream:** interface, navigation, workflow, pain points · **Researched:** 2026-11-06
**Labels:** FACT (stated in source) / INFERENCE (my reasoning). No screenshots or assets were copied.

---

## 1. Window anatomy (FACT)

- **Main menu** is a single "M" button top-left: New / Open / Save / Import / Export /
  Collections / Preferences.
- **Ribbon** across the top: Category tabs → command buttons. A small triangle on an icon opens
  a **command group** flyout. **Command search** sits top-right.
- **Dockable panels** on left/right, floatable and tabbable:
  Dynamic Commands, Quick Commands, Recent Commands, Display Modes, Layers, Dynamic Groups,
  Gem Report, Metal Weights, Projects, Project Actions, Properties, Render Studio.
- **Viewports:** Top, Front, Right and Perspective, four-up by default.
- **Status bar:** version / job bag / project, plus toggles for Auto-Hide, Grid Snap, Ortho,
  Planar, Osnap, SmartTrack, Gumball, Record History, Project; a Context Menu button and a UI
  scale slider.
- **View menu** holds Primary/Secondary layouts and "Reset Window Layout".

INFERENCE: this is a desktop-ribbon paradigm bolted onto Rhino. Every panel is a separate
inspector; nothing is task-sequenced. Our iPad surface must invert that: task-first wizard with
panels summoned by context, not always-on chrome.

## 2. Viewport navigation (FACT)

- Right-drag **rotates** Perspective but **pans** planar views; Shift+right-drag pans Perspective.
- Wheel zooms **toward the cursor**.
- Arrow keys rotate; Shift+arrows pan; Ctrl+Tab cycles viewports; Ctrl/Alt/Shift+right-drag
  drives camera / tilt / lens.
- Grid lines are **1 mm**.
- Display mode icons apply to the **active** viewport on left-click (active viewport has a
  lighter grey frame) and to **all** viewports on right-click; the Display Modes panel supports
  drag-reorder.

## 3. Modelling aids (FACT)

- **Osnaps:** End, Near, Point, Mid, Cen, Int, Perp, Tan, Quad, Knot, Vertex, Project.
- Alongside: Grid Snap, Ortho, Planar, SmartTrack (alignment guides from prior points).
- **Gumball** toggles move/scale/rotate in one widget.
- **Viewport Control Handles (VPCH):** builder parameters can be edited three ways — slider,
  typed value, or drag handle in the viewport. This is the single most important interaction
  idea in the product for our purposes: *parametric values are physically manipulable*.
- **Dynamic Commands** list the editable history tree; hovering a row highlights the geometry
  cyan; the kebab menu offers Style / Hide / Show / Rename / Delete.
- Gems auto-land on cut-type layers that carry render materials.

## 4. Canonical workflow — start to finished ring (FACT, Gemvision Quick Start)

1. Tools → **Ring Rail**, set finger size.
2. **Gem on Ring Rail**: 6 mm round, Z-offset ≈1.5 mm.
3. **Head** (Settings) on the gem; raise with the "Overall Height" VPCH.
4. **Profile Placer** for the top profile; mirror for the second profile.
5. **Profile Sweep 1 with End Caps**.
6. Save a **Job Bag** (project container).
7. Edit Ring Rail → finger size 9; gem, head and profiles re-fit.
8. Swap the centre to an 8.5×6.5 mm oval; the head re-sizes.
9. Add halo/prongs, Boolean, then **Render Studio** or Batch Render.

Documented tutorial titles confirm the same arc: "Three-Stone Engagement Ring Tutorial",
"Wrap Bridal Ring", "How To Create a Full Parametric Halo Ring in MatrixGold",
"From Ring Rail to Production: Building a Signet Ring".

**This eight-step sequence becomes FacetForge acceptance test #1** (see MASTER-PLAN phase 95):
change size 6 → 9 and round 6 mm → oval 8.5×6.5 and the assembly must rebuild without manual
repair.

## 5. Panels and what they imply

| Panel | Function | FacetForge equivalent |
| --- | --- | --- |
| Dynamic Commands | Editable history tree | Feature timeline (phase 77) |
| Display Modes | Shaded / clay / rendered per viewport | Display mode chip in viewport HUD |
| Layers | Visibility, lock, colour, current layer | Layer panel + per-part layers |
| Gem Report | Stone inventory | Stone report (phase 111) |
| Metal Weights | Estimated metal mass | Mass properties (phase 72, 126) |
| Projects / Job Bags | Project container + assets | Document browser (phase 28) |
| Properties | Object metadata | Inspector (phase 36) |
| Render Studio | Materials, lights, camera | Studio panel (phase 130–138) |

## 6. Shortcuts (FACT)

F1 command help · F5 edits selected Dynamic Command · F6 context menu (4.0 also lists Duplicate)
· F4 world origin · Enter commits. Function keys otherwise pass through to Rhino.
Esc-to-cancel is INFERENCE (Rhino convention), not documented.

## 7. Documented pain points → design counters

| Complaint (source) | FacetForge response |
| --- | --- |
| Tools "more difficult to find" and "quite difficult to learn"; requires Rhino knowledge (Haywood's review) | Task-first UI: 5-tool default palette, searchable command palette, guided builders |
| Renderer "just okay", locked 14k-gold preset (McNeel forum) | Editable PBR alloy presets, no locked materials (phase 131) |
| Release notes repeatedly fix empty Layers panel, missing VPCH, broken ribbon search, VPCH↔panel desync, status-bar overflow | Single source of truth for parameter state; UI tests for every control that mirrors it (phase 18/31/165) |
| Bottom bar overflows on small screens | Adaptive chrome + Stage Manager breakpoints (phase 3, 167) |
| Desktop ribbon assumes mouse precision | Pencil-first hit targets ≥44 pt, radial menu, hover previews |

## 8. iPad adaptation principles (INFERENCE)

1. **Three zones, not four viewports**: one hero perspective + optional top/right inset; jewellers
   judge form in perspective and check symmetry in top view.
2. **Parametric handles in situ** (VPCH equivalent) are the differentiator — keep them, enlarge
   them for touch, and pair each with a numeric field.
3. **Nothing is modal**: selecting a stone should surface head-setting tools in a contextual bar,
   which is where desktop MatrixGold makes users hunt.
4. **Undo is the safety net**: every parametric edit must be one undo step.
5. **No Rhino vocabulary** in the UI: no "polysurface", "osnap", "gumball". Use jeweller words
   (shank, gallery, seat, bearing) plus plain-language hints.

## 9. Open questions

- Real MatrixGold render settings (samples, denoiser) were not publicly documented in detail.
- Whether 4.1 changed the ribbon structure vs 3.x is unverified; release notes are bug-fix oriented.
- Job Bag file structure is proprietary/undocumented; we design our own document bundle (phase 25).

## 10. Verification pass (2026-11-06)

A second public-source pass confirmed most of the anatomy above and added these points:

- **Conflict, unresolved:** section 1 records a four-up default layout, but one published review
  states MatrixGold opens with a **single maximised Perspective viewport** (Rhino's own default is
  four views). No vendor page settles it. The plan must not encode either as a fact.
- **FACT** The panel set also includes **Project Manager**, **Content Manager** and
  **Ring Resizer**. Quick Commands became user-tabbed in 3.9 (custom tabs, save/import/share
  templates) and gained tab colours in 3.11.
- **FACT** Rhino's **SelectionFilter** (points, curves, surfaces, polysurfaces, meshes, SubDs,
  blocks, sub-objects) is available; no jewelry-specific filter set is documented. Selection is
  therefore layer-driven in practice.
- **FACT** The Tech Report exports CSV, and metal weights were added to that CSV in 3.11.
- **FACT** VPCH defects are documented across releases: missing handles, a handle attached to the
  wrong gem, panel/handle desync and text-scaling problems. This is evidence that in-viewport
  parametric handles are hard to keep in sync, not evidence against the idea.
- **INFERENCE:** the ribbon is a discoverability layer over Rhino commands. Cloning the ribbon
  would import the discovery problem; the transferable idea is contextual, task-first tool
  surfacing with the same parametric depth.

## Sources

- Quick Start Guide (PDF): https://s3.amazonaws.com/gemvision.com/Images/MatrixGold/GettingStarted/MatrixGold%20Quick%20Start%20Guide.pdf
- Training Guide (PDF): https://s3.amazonaws.com/gemvision.com/Manuals/MatrixGold%202019%20Training%20Guide.pdf
- Rhino 8 shortcuts: http://docs.mcneel.com/rhino/8/help/en-us/user_interface/shortcuts.htm
- 3.11 release notes: https://en.design-engineering.net/matrixgold/matrixgold-3-11
- 3.9 release notes: https://en.design-engineering.net/matrixgold/matrixgold-3-9
- 2.0 release notes: https://en.design-engineering.net/matrixgold/matrixgold20
- Rendering discussion: https://discourse.mcneel.com/t/matrixgold-rendering/223157
- Layers panel thread: https://discourse.mcneel.com/t/rhino-8-feature-layers-panel/142737?page=2
- Independent review: https://www.haywoodsjewellery.co.uk/learning-cad-for-jewellery
- Tutorials: https://www.youtube.com/watch?v=vuMiO0gN4WU · https://www.youtube.com/watch?v=G56--0zOkVQ · https://www.youtube.com/watch?v=_AtFmL1gP8U
