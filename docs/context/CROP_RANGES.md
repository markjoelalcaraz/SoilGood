# SoilGood — Crop ranges (research v1)

Source of truth for **catalog baselines**, **phase timelines**, and **honesty labels**.  
SQL seed: [`supabase_crop_ranges_v1.sql`](supabase_crop_ranges_v1.sql).  
Universal fallback bands: [`insights.json`](../../supabase/functions/soilgood-insights/insights.json).

## Fallback ladder (locked)

1. Exact sourced number for that crop + metric  
2. Labeled family/class proxy (`proxy_cucumber`, `fao_sensitive_class`, …)  
3. Universal `insights.json` bands  

**NPK:** universal **low-only** (N&lt;45, P&lt;20, K&lt;80). No per-crop NPK. No NPK high band.

## Honesty

- Philippine DA/ATI/PhilRice guides almost never publish **capacitive soil-moisture %**. Moisture min/max are **`mapped_v1`** hydro classes, not “DA said 60%.”
- Probe **EC ≠ lab ECe**. Crop `ec_max` from FAO Maas–Hoffman ECe where numbered; salinity ppt ≈ `0.64 × ECe` (`mapped_from_ece`).
- Phase **days** are often `estimated_from_DAT` (DA gives first harvest DAT, not neat 4-phase tables). IRRI reproductive **35** / ripening **30** for rice are explicit.
- Phase care = **overlays** (tighten / dry-down), not invented capacitive % per phase.

## Hydro classes (mapped moisture %)

| Class | Moisture min–max | Crops |
|---|---|---|
| A Paddy | 60–100 | Rice |
| B Moist | 45–80 | Banana Saba, Cabbage |
| C Moist, hate waterlog | 40–75 (tomato wet max 70) | Corn, tomato, eggplant, ampalaya, sitaw, okra, chili, cucumber, squash |
| D Drought-tolerant roots | 30–65 | Cassava, sweet potato, peanut |
| E Allium | 35–70 (late dry-down overlay) | Onion, garlic |

## Global extreme floors (no crop / always)

- Moisture critical dry &lt; 15%; critical wet &gt; 95% (upland; rice class A is the flood exception)
- Temp critical cold &lt; 10°C; critical heat &gt; 42°C

## Warn / critical from crop [min, max]

Span `S = max − min`. Outside ≤ `0.15·S` → warn; &gt; `0.15·S` → critical; global floor → critical.  
Flowering/reproductive/silk/pegging → tighten to `0.10·S`. Dry-down phases → raise wet sensitivity, soften dry warn.

## Phase timelines

See plan + SQL `phases` JSON. Clock: DAT transplanted, DAP direct-seed/clove/cutting/sucker. Veg maturity = first harvest + harvest window.

## 8-in-1 baselines (summary)

| Crop | Moist | Temp °C | pH | EC max | Sal max | Maturity |
|---|---|---|---|---|---|---|
| Rice | 60–100 | 20–35 | 5.5–7.0 | 3.0 | 1.9 | 110 DAT |
| Corn | 40–75 | 18–32 | 5.5–7.0 | 1.7 | 1.1 | 100 DAP |
| Tomato | 40–70 | 18–30 | 5.5–8.0 | 2.5 | 1.6 | 90 DAT |
| Eggplant | 40–75 | 21–30 | 5.5–6.8 | 1.1 | 0.7 | 90 DAT |
| Ampalaya | 40–75 | 22–32 | 6.0–6.7 | 2.5 proxy | 1.6 | 70 DAT |
| Sitaw | 40–75 | 20–35 | 5.5–6.8 | 4.9 | 3.1 | 60 DAP |
| Okra | 40–75 | 20–30 | 5.5–7.0 | 2.0 univ | 1.3 | 70 DAP |
| Cabbage | 45–80 | 15–20 | 6.0–6.8 | 1.8 | 1.2 | 58 DAT |
| Onion | 35–70 | 15–30 | 5.8–6.0 | 1.2 | 0.8 | 110 DAT |
| Garlic | 35–70 | 15–30 | 5.8–6.0 proxy | 3.9 | 2.5 | 105 DAP |
| Chili | 40–75 | 20–30 | 5.5–6.5 | 1.5 | 1.0 | 85 DAT |
| Cucumber | 40–75 | 18–30 | 6.5–7.5 | 2.5 | 1.6 | 70 DAP |
| Squash | 40–75 | 18–30 | 5.5–6.5 | 3.2 proxy | 2.0 | 85 DAP |
| Peanut | 30–65 | 20–30 | 5.8–6.5 | 3.2 | 2.0 | 100 DAP |
| Cassava | 30–65 | 25–30 | 4.4–7.5 | 2.0 univ | 1.3 | 270 DAP |
| Sweet potato | 30–65 | 25–30 | 5.5–6.5 | 1.5 | 1.0 | 110 DAP |
| Banana Saba | 45–80 | 27–30 | 4.5–7.5 | 1.0 class S | 0.6 | 450 DAP |

## Apply in Supabase

```text
1. supabase_schema.sql (if new project)
2. supabase_crops_home_ai.sql
3. supabase_crop_ranges_v1.sql   ← this catalog refresh
```

## Key sources

- DA-RFO2 / ATI production guides (veg temp, pH, irrigation habits)
- PhilRice / PalayCheck / IRRI (rice stages, water depth, heat)
- FAO Annex 1 Maas–Hoffman ECe; FAO-56 Kc stage water use
- BPI garlic guide
