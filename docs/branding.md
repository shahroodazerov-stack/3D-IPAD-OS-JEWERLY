# Branding sheet — Phase 0

Working name, bundle identifier, palette seed and icon concept for the original app. This is a
clean-room product: nothing here is copied from MatrixGold, and the name is a working title
pending a trademark search before any public release.

## Name

**FacetForge** — the faceting of a gem and the forging of metal, in one word. It describes the
two halves of the product (gem design, metal CAD) without borrowing a competitor's name,
initials or trade dress.

- Product name in UI: `FacetForge`
- Short name / home-screen label: `FacetForge`
- URL-safe slug: `facetforge`
- Bundle identifier: `com.shahroodazerov.facetforge`
- Test bundle identifier: `com.shahroodazerov.facetforge.tests`
- Document type: `com.shahroodazerov.facetforge.document`
- Minimum OS: iPadOS 26.0 (iPhone companion later, same bundle)

## Palette seed

The palette is a seed, not a finished theme: Phase 3 turns these into semantic tokens and tests
contrast. Values are sRGB hex, chosen to sit between a dark workshop and a bright showroom.

| Token | Hex | Use |
| --- | --- | --- |
| `ink` | `#14161A` | Canvas background, viewport surround |
| `graphite` | `#2A2E35` | Panels, toolbars, dividers |
| `porcelain` | `#F4F1EA` | Primary text on dark, document paper |
| `metal` | `#C8A15A` | Accent, selected tools, measurement highlights |
| `metal-dim` | `#8C6F3F` | Pressed/disabled accent |
| `gem` | `#1F6F78` | Gem-related affordances, gemstone tags |
| `gem-bright` | `#39A7AE` | Hover/focus on gem affordances |
| `warning` | `#C4553B` | Manufacturing violations, destructive actions |
| `success` | `#3E7C59` | Passed checks, saved state |

Rules for Phase 3: the viewport stays neutral so metal colour is judged against a known grey;
selection uses `metal` plus a 2 pt outline, never colour alone; every semantic pair reaches
WCAG 2.2 AA for text and 3:1 for non-text controls; no gradients on precision tools.

## Typography

- UI: **SF Pro** (system), Dynamic Type from xSmall to accessibility XXXL.
- Numeric fields and dimensions: **SF Mono** (system monospaced) with tabular figures.
- Document titles: **New York** (system serif), display sizes only.
- No bundled third-party fonts in v1.

## Icon concept

A single brilliant-cut crown seen from above, reduced to six straight facets, with the negative
space between the two largest facets forming an **F**. Drawn on a 1024 px grid, one colour plus
`metal`; no photograph, no gemstone render, no letters other than the negative-space F.

- Small sizes: 20/29/40/60 pt use the solid facet silhouette; the F is omitted below 40 pt.
- Alternate: monochrome template variant for the menu bar and document badges.
- App Store: ink background, metal facet edges, no text.
- Original artwork only; the icon is authored in Phase 3 and committed as SVG plus PNG exports.

## Voice

Precise, quiet, workshop-direct. Say "seat depth is 0.2 mm too deep for this prong" rather than
"something went wrong". Units are always shown. Warnings name the rule and its source (standard
or vendor/trade rule) so a jeweller can decide, not just obey.

## Originality note

The name, palette, icon and copy above are original to this project. Competitor screenshots
are used only as behavioural research, never as assets; no competitor logo, icon, font, help
text or code enters the repository. See `docs/legal/provenance.md` and ADR-004.
