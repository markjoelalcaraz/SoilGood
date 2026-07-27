# SoilGood — UI Theme

## Brand direction
Clean, minimalist, editorial look. Practical for farmers on mobile — clear hierarchy, high contrast, calm greens.

## Colors
| Role | Value | Usage |
|---|---|---|
| **Primary green** | `#4A7C59` | Buttons, icons, important headers, brand accents |
| **Matte white** | `#FFFFFF` | Main background |
| **Surface / cards** | Soft off-white / light gray | Cards and surfaces for depth without leaving the matte-white feel |
| **Text** | Dark charcoal **or** deep forest green | Body and labels for readability on white |

Suggested text tokens (lock in code theme):
- Charcoal: e.g. `#2C2C2C` (or similar dark charcoal)
- Deep forest (optional for emphasis): e.g. `#1B4332` / close match to brand greens

## Typography
| Role | Font | Usage |
|---|---|---|
| **Headlines** | **Literata** (serif) | Main page titles and large headers — premium editorial feel |
| **Body / labels** | **Nunito Sans** (sans-serif) | Functional text, sensor values, labels — easy mobile reading |

### Type details
- **Weights:** Bold / Semi-bold for hierarchy; Regular for long content.
- **Line height:** ~**1.6** for comfortable reading.
- **Alignment:** Branding in top bar is **center-aligned**; most data cards / content are **left-aligned** for fast scanning.

## Shell & layout
- Persistent app shell (nav stays); content area only changes.
- Skeleton loaders match real layout (cards/rows), not random shapes unrelated to the page.
- Prefer reusable themed buttons/cards over one-off styles.

## Implementation notes (when coding)
- Load Literata + Nunito Sans via `google_fonts` or bundled assets.
- Centralize colors/text styles in one theme file so pages stay consistent.
