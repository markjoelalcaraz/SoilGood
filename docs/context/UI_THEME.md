# SoilGood — UI Theme

## Brand direction
Family-friendly farm look. Practical for farmers on mobile — illustrated plots, light green actions, calm cards. The older editorial green (`#4A7C59`) is kept in `design/original/` for revert.

## Colors
| Role | Value | Usage |
|---|---|---|
| **Primary green** | `#62A844` | Icons, links, brand accents |
| **Button green** | `#6AAF45` | Filled buttons. Dark text `#243028`. Splash and login buttons use white text |
| **Nav pill** | `#C8EEB0` | Selected bottom-nav chip. Icon `#4E9434` |
| **Page background** | `#F6F8F3` | Scaffold behind white cards |
| **Matte white** | `#FFFFFF` | Cards |
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
- **Phone-first:** layouts must fit ~320–360px wide phones without overflow (notches, keyboard, bottom nav). On large screens, body content caps at **600px** centered; AppBar + bottom nav stay full width. See `.cursor/rules/page-architecture/responsive-ui.mdc`.
- **Pull-to-refresh:** any screen that shows live/fetched data must be pullable. See `.cursor/rules/page-architecture/pull-to-refresh.mdc`.
- **Scrollbars:** thin overlay (4–6px, no track, auto-hide). Never the thick OS/Chrome bar. See `.cursor/rules/page-architecture/scrollbar.mdc`.

## Implementation notes (when coding)
- Load Literata + Nunito Sans via `google_fonts` or bundled assets.
- Centralize colors/text styles in one theme file so pages stay consistent.
