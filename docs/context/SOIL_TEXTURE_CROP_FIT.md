# SoilGood — Soil texture × crop fit (research v1)

> **Purpose:** Grounded baselines for farmer-selected **soil texture** in crop suitability (third pillar beside 8-in-1 chemistry + weather).  
> **Not** NCCAG GIS — that stays future: [`FUTURE_ENHANCEMENTS_SOIL.md`](FUTURE_ENHANCEMENTS_SOIL.md).  
> Optional **soil series** can override texture in match scoring: [`SOIL_SERIES_CROP_FIT.md`](SOIL_SERIES_CROP_FIT.md).

## Farmer texture enum (v1)

Simplified USDA-style feel classes (same language as PhilRice Simplified Keys textural classes, condensed for UX):

| Code | Label (app) | Feel hint |
|---|---|---|
| `sandy` | Sandy | Gritty; water drains fast |
| `sandy_loam` | Sandy loam | Mostly gritty; still holds some water |
| `loam` | Loam | Balanced grit / smooth / sticky |
| `clay_loam` | Clay loam | Sticky with some grit |
| `clay` | Clay | Very sticky; holds water; slow drainage |
| `unknown` | Not sure | No texture weight in match score |

Store on `farms.soil_texture` (nullable → treat as `unknown`). Editable later on Profile.

## Scoring rule (proposed for implement)

For each catalog crop:

- Texture in **preferred** → full texture points  
- Texture in **acceptable** → partial points  
- Texture in **caution** → low / penalty points (still show crop; reason explains drainage / digability)  
- `unknown` → skip texture factor (chemistry + weather only)

Exact weights live in `lib/features/crops/data/crop_texture_fit.dart`; this doc owns **preferred / acceptable / caution** lists.

## Per-crop texture fit (17 catalog crops)

| Crop | Preferred | Acceptable | Caution | Source notes |
|---|---|---|---|---|
| Rice (Palay) | clay, clay_loam | loam | sandy, sandy_loam | Wetland rice wants clayey, less permeable soils to hold flood (PIDS/PASCN land suitability discussion). |
| Corn (Mais) | loam, sandy_loam | clay_loam | clay, sandy | PH lit: best in loam / silt loam; avoid heavy clay & very sandy (ATI cited in Muñoz GIS study; PIDS: almost any except sandy & heavy clay). |
| Tomato | sandy_loam, clay_loam | loam | clay, sandy | ATI / DA-RFO2: sandy loam to clay loam, well-drained; flood-sensitive. |
| Eggplant | sandy_loam, clay_loam | loam | clay, sandy | DA-RFO2 eggplant guide: thrives best in sandy loam and clay loam. |
| Ampalaya | sandy_loam, loam | clay_loam | clay, sandy | PCAARRD iVeg: preferably deep well-drained sandy loam or silty loam. |
| Sitaw | loam, sandy_loam | clay_loam | clay, sandy | ATI sitaw guide: fertile, friable, well-drained; raised beds if drainage poor. |
| Okra | sandy_loam, loam | clay_loam | clay, sandy | DA-RFO2 okra: silty to sandy loam, well-drained. |
| Cabbage | sandy_loam, loam | clay_loam | clay, sandy | DA-RFO2 cabbage: best in sandy loam. |
| Onion | loam, sandy_loam | clay_loam | clay, sandy | DA-RFO2 onion: friable, well-drained loam; dry-down for bulb maturity. |
| Garlic | sandy_loam, loam, clay_loam | — | clay, sandy | BPI garlic guide: sandy, silt, and clay loam recommended for commercial production; well-drained. |
| Chili | sandy_loam, clay_loam | loam | clay, sandy | DA-RFO2 pepper: best in sandy loam to clay loam, good drainage. |
| Cucumber | loam, sandy_loam | clay_loam | clay, sandy | DA-RFO2 cucumber: fertile OM-rich soil; raised beds in wet season (drainage). Texture often implied loam family. |
| Squash | sandy_loam, clay_loam | loam | clay, sandy | DA-RFO2 squash: best in well-drained sandy loam and clay loam. |
| Peanut | sandy_loam, loam | clay_loam | clay, sandy | Region 2 peanut tech: sandy loam preferred; well-drained friable soil; heavy clay hinders pegging/harvest. |
| Cassava | sandy_loam, clay_loam | loam | clay, sandy | PH production guides: sandy loam or clay loam; not waterlogged / shallow / stony. |
| Sweet potato | sandy_loam, loam | clay_loam | clay, sandy | DA-RFO2 + Tarlac suitability lit: well-drained sandy loam desired; heavy clay delays / distorts roots; waterlog → rot. |
| Banana Saba | loam, clay_loam | sandy_loam | sandy, clay | DA-RFO10 Saba guide: nearly all soils, but deep friable loam best; avoid extreme sandy and very rocky. |

### Family proxies (honesty)

- **Cucumber:** DA-RFO2 guide emphasizes fertility/pH/drainage more than named texture; we map to loam family (same as other cucurbits with explicit sandy/clay loam). Label in catalog meta: `texture_basis: family_proxy_cucurbit` if needed.  
- **Sitaw / “friable”:** mapped to loam / sandy_loam preferred.  
- **Rice:** lowland flooded system — clay preference is for **paddy water retention**, not upland aerobic rice.

## What this is not

- Not a substitute for lab texture analysis or BSWM soil series ID.  
- Not parcel-level DA suitability (that is NCCAG).  
- Sensor 8-in-1 **cannot** measure % sand/silt/clay — farmer pick (or future map lookup) is required.

## Key sources

1. DA AMIA — [NCCAG overview](https://amia.da.gov.ph/national-color-coded-agricultural-guide-nccag-map/) (future map path; not used as v1 scoring table).  
2. PIDS Discussion Paper 2003-03 — wetland rice clayey / less permeable; corn limits on sandy & heavy clay.  
3. DA-RFO2 HVCDP production guides — tomato, eggplant, okra, cabbage, onion, squash, pepper, sweet potato, cucumber.  
4. ATI e-Extension — tomato, sitaw.  
5. PCAARRD iVeg — ampalaya soil.  
6. BPI — garlic production guide.  
7. DA-RFO10 — Saba banana production guide.  
8. PhilRice Simplified Keys / PSIS — texture class language for farmer feel-test (not series auto-detect).  
9. Region 2 peanut production technology summaries; PCAARRD confectionery peanut pubs.  
10. Muñoz / Mati PH soil–crop papers — corn loam preference; root crops favor sandier loams.

## Related

- Catalog chemistry ranges: [`CROP_RANGES.md`](CROP_RANGES.md)  
- Crops page: [`../pages/crops.md`](../pages/crops.md)  
- Onboarding: [`../pages/onboarding.md`](../pages/onboarding.md)  
- Future GIS / series: [`FUTURE_ENHANCEMENTS_SOIL.md`](FUTURE_ENHANCEMENTS_SOIL.md)
