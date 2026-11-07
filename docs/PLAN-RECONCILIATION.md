# Plan reconciliation — v1.0 → v1.1

**Date:** 2026-11-06 · **Plan:** `docs/MASTER-PLAN.md` v1.1 · **Owner:** shahroodazerov-stack
**Inputs:** `docs/research/00-findings-and-constraints.md`, the three pass-2 threads
(`g-rendering-materials.md`, `h-production-interchange.md`, `i-competitive-kernels.md`), and the
verification subsections added to `b-matrixgold-ux.md`, `c-jeweler-domain.md` and
`d-cad-kernel.md`.
**Scope:** documentation only. No phase was implemented, no application code was changed, and
the 200-phase structure, 12 arcs and `scripts/check-plan.sh` invariants were preserved.

**Verdict:** the five named contradiction classes are resolved in the plan. All 200 phase rows
still carry a `CI:` acceptance and a backward-only dependency chain. Any remaining uncertainty is
listed in §6 rather than papered over.

---

## 1. Why this reconciliation was needed

`docs/MASTER-PLAN.md` v1.0 was written before the pass-2 research added threads G–I and before
the verification subsections changed two facts and added several constraints. The audit found:

1. A rendering path that could be read as expecting RealityKit to provide gem refraction and
   dispersion, which Apple does not document.
2. Export language that grouped 3MF with MatrixGold parity, although MatrixGold documents
   STL/3DM/OBJ and 3MF/SLC are Rhino-side exports.
3. No explicit dependency/licence gate in the phase rows, despite OCCT and CGAL being unsuitable
   for a closed-source App Store app without a commercial licence or counsel.
4. A default-viewport decision that read like an inherited fact even though the public evidence
   conflicts.
5. Product wording that could be quoted as an identity claim ("exactly like MatrixGold").
6. Several acceptance criteria that were visual, device-bound or dependent on third-party tools
   without saying so, plus one wrong evidence reference (phase 113 pointed at 97).

The fixes are surgical. No phase was renumbered, no arc changed, and no phase was deleted or
merged.

---

## 2. Decisions now locked in the plan

| Decision | Value in v1.1 | Authority | Where recorded |
| --- | --- | --- | --- |
| Kernel | Hybrid exact parametric curves/surfaces over a watertight mesh-solid kernel; no B-rep rewrite in v1 | Dossier D; ADR-001 | Plan §0, ADR-001 |
| Dependencies | Apple frameworks only in v1; permissive third-party only after provenance and licence review; OCCT, CGAL, GPL and AGPL blocked absent a commercial licence and counsel | Dossier I; ADR-007 | Plan §0, non-negotiable 8, phase 194 |
| Rendering | RealityKit supplies PBR/IBL and the viewport; the gem refraction/dispersion pass is custom Metal, not a RealityKit material | Dossier G; ADR-002 | Plan §0, ADR-002, phases 132–133 |
| Exchange | STL and OBJ are the MatrixGold-documented parity set; 3MF is an additional FacetForge format; 3DM is deferred to v1.1; SLC is out of scope | Dossier H | Plan §0, phases 152–154, traceability table, Appendix A |
| Default viewport | Single maximised Perspective with optional Top/Right inset; four-up is a preset | Dossier B records conflicting evidence; this is a deliberate product choice | Plan §0, phase 13 |
| Claims | Behavioural workflow parity only; never "exactly like", "clone" or "the same as"; no competitor marks in product or store metadata | Dossier 00 §5; ADR-004 | Plan §0, non-negotiable 8, phase 193 |
| Performance evidence | Simulator timings are regression baselines; device frame rate, memory, thermal, startup and export timings require a `docs/evidence/phase-NNN.json` record | Dossier 00 §2.1, §4 | Plan §1, phases 9/13/54/75/113/137/143/183 and the evidence list in §5 |

---

## 3. Phase-by-phase amendments

Every row below changed in v1.1. Phases not listed were read against the same constraints and
needed no edit. The grouping is by the constraint that forced the change, not by arc.

### 3.1 Rendering, performance and presentation

| Phase | Problem found | Amendment |
| --- | --- | --- |
| 9 | Acceptance claimed "60 fps in the simulator", which is not a device claim and is not a stable runner assertion | Replaced with a default-layout render assertion plus a stored frame-time regression baseline; simulator numbers are explicitly not device performance |
| 13 | The default layout was not chosen deliberately, and "CPU submit < 8 ms" was unqualified | Fresh documents now open in the chosen single maximised Perspective; four-up is a preset; CPU submit is a stored baseline and device budget is phase 143 evidence |
| 19 | "Labels remain legible" was subjective | Text must be at least 9 pt and unclipped at three zoom levels |
| 54 | "16 ms per update" could be read as a device promise | Marked runner-relative and explicitly not a device-performance claim |
| 75 | "On device class hardware" was asserted inside CI | Runner thresholds are enforced in CI; device-class timing is phase 75 evidence |
| 113 | Evidence reference pointed at phase 97 and the timing was unqualified | Now `check-evidence.sh 113`, with the iPad Air (M3) timing in the phase-113 record; the unit test still proves unchanged features are not rebuilt |
| 124 | "Scrubbing is smooth at 60 fps" was not a measurement | Scrubbing must hold p95 frame time at or below 16.7 ms on the runner baseline |
| 130 | "No seams in the reflection" was visual | 360° rotation in 1° steps; adjacent frames must differ by at most 2 % luminance across the seam column; each HDRI stays under 6 MB |
| 131 | The gold colour was checked against a third-party "Filament value" that is not part of this project | Checked against the alloy table's own cited reference value |
| 132 | Gem shader was not labelled as ours and "visible brilliance and fire" was subjective | Custom Metal shader, not a RealityKit built-in; a golden fixture fails if the internal-reflection term is disabled; body colour is within ΔE < 3 of the preset |
| 133 | Same renderer ambiguity; the performance part was already evidence-gated | Custom Metal pass, approximation explicitly not spectral path tracing; the device budget remains phase 133 evidence |
| 134 | "Shadow acne-free" and "without lag" were visual | Depth-bias sweep must show zero acne pixels on the 0.1 mm fixture; contact-shadow screen offset must stay at or below 1 px over 30 frames at 60 Hz |
| 136 | Evidence path and validator invocation were ambiguous | Now points at `docs/evidence/phase-136.json` and `check-evidence.sh 136` |
| 137 | Draft frame time could be read as a device claim | Marked runner-relative |
| 141 | "Legible at 2× and never clipped" was visual | Overlay text must compute to at least 12 pt at 2× and sit fully inside the image bounds in snapshot tests |
| 144 | "P3 screens do not oversaturate" cannot be proven on a hosted runner | A P3 fixture conversion must keep saturated primaries in gamut with no channel clipping; hardware display accuracy is explicitly not claimed |
| 146 | Evidence path and validator invocation were ambiguous | Now points at `docs/evidence/phase-146.json` and `check-evidence.sh 146` |

### 3.2 Jewellery and manufacturing

| Phase | Problem found | Amendment |
| --- | --- | --- |
| 104 | "Rebuilds the halo count correctly" was not a value assertion | Halo count must equal the fixture table's expected value after a centre-stone change; only the 0.15 mm lower bound is enforced, because the 0.15–0.30 mm band is a trade convention |
| 147 | "Calliper fixture" implied a physical measurement inside CI | Thickness must match the fixture's analytic wall thickness within 0.02 mm; the 0.30 mm wall remains a test fixture, not a manufacturing minimum |
| 152 | "Imports into two independent slicers" is not executable on the hosted runner | CI uses a spec-independent STL reader in the test target (welds coincident vertices, closed 2-manifold, positive signed volume, mm units); the two slicer imports are recorded in `docs/evidence/phase-152.json` and accepted by `check-evidence.sh 152` |
| 153 | 3MF was presented as parity | Retitled "3MF export (additional format)"; the deliverable and report label it as a FacetForge addition, not MatrixGold parity |
| 154 | "MTL opens in a third-party viewer" was external and unrecorded | CI uses an independent MTL fixture parser that resolves every material and map path; a third-party viewer import is recorded in `docs/evidence/phase-154.json` and accepted by `check-evidence.sh 154` |
| 156 | "Reduces overhang area measurably" had no threshold | Must reduce overhang area by at least 20 % versus the worst orientation on 10 fixtures |
| 157 | The casting-tree phase did not say who owns sprue/support responsibility | The proposal now states who adds supports and sprue for the selected manufacturer profile |

### 3.3 Interaction, accessibility and identity

| Phase | Problem found | Amendment |
| --- | --- | --- |
| 24 | Palm rejection was mentioned but the evidence file was not validated by name | Now `check-evidence.sh 24` with `docs/evidence/phase-024.json` |
| 163 | "Pressure response without jitter" was visual | 100 strokes must show monotonic width across 10 fixed pressures with less than 5 % width variation at constant pressure |
| 169 | VoiceOver evidence was referenced without the validator invocation | Now `docs/evidence/phase-169.json` and `check-evidence.sh 169` |
| 170 | Keyboard-only evidence had the same gap | Now `docs/evidence/phase-170.json` and `check-evidence.sh 170` |
| 174 | "RTL mirrors correctly" was subjective | RTL snapshots must match the mirrored baseline for navigation and toolbars, with zero clipped strings under pseudo-localisation |
| 175 | "Visual review" was not a gate | Asset scan, icon snapshots at three sizes inside safe-area margins, and `check-evidence.sh 175` for the visual review |

### 3.4 Reliability, release and legal

| Phase | Problem found | Amendment |
| --- | --- | --- |
| 183 | The stress phase mixed runner measurements with device performance | Opens under 8 s and saves under 3 s on the runner; orbit must not regress against the phase-183 baseline; device performance is phase 179/180 evidence |
| 186 | App Store Connect validation cannot run in CI | Manifest schema and required-reason API inventory run in CI; App Store Connect validation is `check-evidence.sh 186` |
| 188 | A physical two-device conflict cannot run in CI | A two-container conflict simulation runs in CI; the physical device conflict is `check-evidence.sh 188` |
| 189 | "Clean checkout verifies green in under 15 minutes locally" mixed a local and a CI claim | A clean checkout must run `scripts/verify.sh` green and record its wall-clock duration; the same script is the local entry point |
| 190 | "Ten consecutive green runs" had no checkable mechanism | Added `scripts/check-ci-history.sh`; it verifies the last ten `ios.yml` runs on `main` are green and none exceeded 45 minutes |
| 193 | No automated claim scan existed | Added `scripts/check-release.sh` metadata and claims scan; it fails on a competitor mark or an "exactly like"/"clone"/"same as" claim |
| 194 | The NOTICE gate allowed LGPL with an unspecified "approved relink plan" | Now fails on any unlisted package, anything outside the MIT/BSD/Apache-2.0/MPL-2.0-core allowlist, or GPL/AGPL; OCCT/CGAL additionally require a commercial licence and counsel sign-off. This enforces ADR-007 |
| 195 | "A jeweller completes the workflow" was an unrecorded human judgement | `check-evidence.sh 195` requires the record |
| 196 | "A new contributor builds and ships" was unrecorded | `check-evidence.sh 196` requires the record |
| 197 | "Every capability marked" had no machine check | Added `scripts/check-traceability.sh`; it fails when a dossier A §4 capability lacks a status and phase reference |
| 198 | The sign-off run did not name the report generator or the evidence gate | `scripts/release-report.sh` regenerates every Appendix A bar; `check-evidence.sh 198` accepts the on-device record; any missing bar fails |
| 199 | "Release notes approved" and "rollback tested" were unrecorded | `check-release.sh` reports zero open P0/P1; `check-evidence.sh 199` accepts release approval and a tested rollback drill |

### 3.5 Global (non-phase) edits

| Location | Change |
| --- | --- |
| Plan header | Version 1.1; status now records phases 0–12 green, 188 remaining; inputs now cite the A–I dossier |
| Mission | 3MF explicitly separated from parity; "exactly like"/"clone"/"same as" prohibited in product and store claims |
| Product decisions | Added default viewport, render detail, dependencies and export-format rows |
| Non-negotiables | Added clause 8: claims and licences |
| §1 | Added the performance evidence rule (simulator baselines vs device records) |
| Architecture at a glance | ADR-002 clarified for the custom gem pass; ADR-007 added |
| Milestone 10 | Now reads "Validated STL + OBJ (parity) and 3MF (our addition)" |
| Phase 0 | Dossier expectation changed from six files to the indexed A–I set |
| Feature traceability | STL/OBJ labelled as the documented parity set; 3DM explicitly deferred; SLC explicitly out |
| Appendix A | Export bar now says watertight STL, with 3MF labelled as our additional format |
| ADR register | ADR-002 amended; ADR-007 added (dependency and exchange licence gate) |
| Provenance | Streams G–I retained and the reconciliation recorded; no new sources added by this pass |

---

## 4. Constraint audit in detail

### 4.1 CAD kernel and dependencies

- **No phase row names OCCT, CGAL, GPL or AGPL as a dependency.** The only mentions in the plan
  are the prohibition in the product decisions, non-negotiable 8, ADR-007 and phase 194. The
  geometry phases (5–8, 42, 56, 62–78) implement their own math, curves, meshes and booleans.
- **ADR-007 is now the gate.** v1 ships Apple frameworks only. A future dependency must be
  permissive, recorded in `docs/legal/provenance.md`, and listed in NOTICE; OCCT/CGAL require a
  commercial licence and counsel, and GPL/AGPL is always rejected.
- **No v1 phase depends on 3DM.** The traceability table says 3DM read/write is deferred to v1.1
  and would need an openNURBS licence review. Phase 152/154 do not require it.
- **Residual risk:** a later phase could add a dependency without updating the register. Phase 194
  fails the build if the NOTICE list is incomplete, but it cannot detect code copied without a
  package manifest. The provenance review remains a human legal step, recorded as evidence.

### 4.2 Rendering and materials

- Dossier G verified that RealityKit documents PBR, IBL, meshes and `LowLevelMesh`, but no gem
  refraction or dispersion model. The plan no longer implies otherwise.
- Phase 129 is the PBR material model; phases 130 and 136 are IBL and studio presets; phases
  132–133 are the **custom Metal** gem pass. Phase 133 explicitly calls dispersion an
  approximation, not spectral path tracing.
- Device frame budgets are evidence-gated at 133, 136 and 143; 179–181 add scene, memory and
  thermal evidence. Simulator numbers are baselines only.

### 4.3 Production and interchange

- MatrixGold documents **STL, 3DM and OBJ**. The plan now treats **STL and OBJ** as the parity
  set, **3MF** as an additional format, **3DM** as deferred, and **SLC** as out of scope.
- The traceability table, milestone 10 and Appendix A were all updated so a reader cannot infer
  3MF/SLC parity from a summary.
- Phase 152 still asserts watertightness, positive signed volume and explicit mm units in CI. The
  two-slicer check moved to an evidence record because slicers are not installed on the runner.
- Phase 154 still asserts bounds, group count and material/map resolution in CI; the third-party
  viewer check is evidence.

### 4.4 Default viewport

The public evidence genuinely conflicts: one review describes a single maximised Perspective,
while the earlier dossier describes four-up. The research file keeps the conflict open. The plan
now makes a **deliberate product choice** — single maximised Perspective, four-up as a preset —
and phase 13 asserts it with a snapshot. It does not claim this is what MatrixGold ships.

### 4.5 Product and store claims

- The only occurrences of "exactly like", "clone" and "same as" in the plan are prohibitions and
  the phase-193 scanner.
- The product name, bundle id, README and branding sheet contain no competitor mark or
  affiliation claim. Research and ADR files name competitors only for factual citation.
- Phase 193's `scripts/check-release.sh` is the automated gate for store metadata, screenshots
  and keywords.

### 4.6 Standards and manufacturing defaults

- Phase 104 enforces only the 0.15 mm lower bound of the halo band; the upper figure is a trade
  convention.
- Phase 147's 0.30 mm wall is a test fixture, not a manufacturing minimum.
- Phase 149's shrinkage ranges are labelled vendor/process guidance, not standards.
- Phase 157 now states who owns sprue/support responsibility for the selected profile.
- No phase claims ISO 8653 or GIA compliance without a matching implementation and test.

### 4.7 Evidence and performance

- 200 phases, 174 fully runner-checkable, 26 with an evidence component. The 26 are:
  24, 75, 113, 133, 136, 143, 146, 152, 154, 169, 170, 175, 178, 179, 180, 181, 182, 186, 188,
  192, 194, 195, 196, 198, 199, 200.
- All 26 are future phases (none of 1–12). No completed phase depends on an evidence record.
- There are currently **zero** `docs/evidence/phase-*.json` records. That is correct at this
  stage: the evidence phases have not been built. When one lands, the record must be committed
  and `check-evidence.sh N` must pass; the workflow already runs `check-evidence.sh` on every
  push.
- The evidence validator intentionally validates records that exist. It does not fabricate a
  record for a phase that was never implemented. The phase acceptance and the PR checklist are
  what force the record to be added at the right time.

---

## 5. Gate audit — all 200 phases

| Check | Result | Detail |
| --- | --- | --- |
| Exactly 200 continuous phase rows | **PASS** | `scripts/check-plan.sh`: 200 rows, 12 arcs, axis mix spec 45 / correctness 88 / design 55 / concision 12 |
| Every acceptance starts with `CI: ` | **PASS** | Enforced by `check-plan.sh`; all 200 pass |
| No banned non-checkable phrases | **PASS** | `check-plan.sh` rejects TBD, placeholder, plausibl, acceptabl, judged, review note, feels, reasonabl |
| Backward-only dependencies | **PASS** | No forward or self dependency; phase 1 alone may depend on phase 0 |
| Phase 0 artefacts present | **PASS** | 28 required files checked (now includes the A–I index, pass-2 threads and this record) |
| Evidence references | **PASS (shape)** | 26 distinct phases name `check-evidence.sh N`; all records will be added at phase time |
| Workflow structure | **PASS** | `check-workflow.sh`: YAML parsed; actionlint not installed, structural fallback used as documented |
| Xcode project/scheme | **PASS** | `check-project.sh` |
| Static gate | **PASS** | `bash scripts/ci-local.sh --static` |
| Citation audit | **PASS with notes** | 176 URLs: 173 `ok`, 2 `ok_suspect` (bare vendor hosts), 1 `http_4xx` (403 bot block with explanatory note) |
| Full iOS build/test locally | **NOT RUN / IMPOSSIBLE** | Windows host has no Xcode, Swift or simulator; a green iOS claim must come from Actions |
| New CI run for this docs-only change | **NOT RUN** | No push or workflow dispatch was made by this pass |

**At this stage of the build:** phases 1–12 are complete and carry runner-executable acceptance;
none needs an evidence record. Phases 13–200 all have a `CI:` acceptance; 26 of them additionally
require an evidence record when implemented. No phase is left with only a human judgement.

---

## 6. Residual uncertainty and explicit non-claims

1. **MatrixGold's true default viewport remains unresolved.** The plan's choice is ours, not a
   factual claim about the vendor.
2. **Device performance, thermal behaviour, jetsam limits, TestFlight and App Store acceptance
   are unverified.** They are evidence phases, not current results.
3. **The 26 evidence records do not exist yet.** A phase in that set cannot be marked green
   without its record. This is a deliberate future gate, not a missing current result.
4. **No STEP/B-rep exchange in v1.** 3DM is deferred; OCCT/CGAL are blocked; no phase silently
   depends on them.
5. **No 3MF/SLC parity claim.** 3MF is our additional output; SLC is a Rhino-side legacy format
   and is not in v1.
6. **Vendor minima are defaults, not standards.** The plan labels them and tests the configured
   value plus the source name, not universal truth.
7. **Clean-room limits remain binding.** No vendor binary, asset, text, icon, screenshot,
   material, HDRI or preset was copied. Research names competitors only for citation.
8. **The four pre-existing render files in the working tree were not touched.** They are outside
   this documentation pass.

---

## 7. Verification log

| Command | Result |
| --- | --- |
| `bash scripts/check-plan.sh` | PASS — 200 phases, 12 arcs, axis mix |
| `bash scripts/check-evidence.sh` | PASS — 0 existing records valid |
| `bash scripts/check-workflow.sh` | PASS — workflow structurally valid; actionlint unavailable |
| `bash scripts/check-project.sh` | PASS — project, scheme and target present |
| `bash scripts/ci-local.sh --static` | PASS |
| `python scripts/check-links.py` | 176 URLs checked; 173 ok, 2 ok_suspect, 1 http_4xx with note |
| `git diff --check` | PASS — no whitespace errors |
| Full iOS build/test | not run; host is Windows and has no Xcode/Swift/simulator |
| New Actions run | not run; this pass did not push or dispatch |

The citation audit regenerated `docs/evidence/link-status.json` and `link-status.md`; those are
the recorded fetch results, not new research claims.

---

## 8. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | 2026-11-06 | Original 200-phase spec |
| 1.1 | 2026-11-06 | Reconciled with dossier A–I: custom Metal gem path, licence gate (ADR-007), export parity corrected, deliberate viewport choice, claim prohibition and scanner, performance-evidence boundary, 42 phase acceptances tightened, provenance restored to A–I |

Files changed in v1.1:

- `docs/MASTER-PLAN.md` — header, decisions, non-negotiables, performance rule, ADR references,
  milestone 10, 42 phase rows, traceability table, Appendix A.
- `docs/adr/README.md` — ADR-002 amended, ADR-007 added.
- `docs/legal/provenance.md` — streams A–I and the reconciliation entry.
- `docs/research/00-findings-and-constraints.md`, `b-matrixgold-ux.md`,
  `g-rendering-materials.md`, `h-production-interchange.md`, `i-competitive-kernels.md` — plan
  status notes that close the loop without changing the findings.
- `scripts/check-plan.sh` — Phase 0 artefact list extended to the A–I index, pass-2 threads and
  this reconciliation record.
- `docs/evidence/link-status.json`, `link-status.md` — regenerated by the citation audit; these
  are fetch records, not new research claims.
- `docs/PLAN-RECONCILIATION.md` — this record.

No application source, test, workflow or asset file was modified by this pass. The four
pre-existing render files in the working tree remain uncommitted and untouched.
