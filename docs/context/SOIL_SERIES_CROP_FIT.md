# SoilGood — Soil series × crop fit (research v1)

> **Purpose:** Optional BSWM/PhilRice **soil series** as a stronger physical pillar for crop match.  
> **NCCAG GIS** stays future-only: [`FUTURE_ENHANCEMENTS_SOIL.md`](FUTURE_ENHANCEMENTS_SOIL.md).  
> **Texture** remains required when series is unknown: [`SOIL_TEXTURE_CROP_FIT.md`](SOIL_TEXTURE_CROP_FIT.md).

## Scoring rule (locked)

```
if farm.soil_series is a curated catalog code
  → use series × crop fit for the physical pillar; IGNORE texture
else if series is null / skip / other
  → use texture × crop fit (current behavior)
chemistry (8-in-1) + weather = always
```

Typical feel lives on the **catalog** (not stamped as a second farmer truth). Farmer `soil_texture` stays what they felt; UI may show “Typical feel: …” as a hint only.

## Honesty

- PhilRice PSIS suitability is often **province-specific** and rates commodity groups (**rice / diversified / root / maize / onion / tomato / banana**), not every SoilGood vegetable by name.
- We map groups → catalog crops (below). Label: `series_basis: philrice_group_proxy` where no per-crop cell exists.
- Same series can flip locally (e.g. Capiz acidity → corn N1). SoilGood encodes **typical** management guidance, not absolute national law.
- Series ID without a field key / AEW is uncertain — hence **optional** + Skip.

### Crop groups → SoilGood names

| Group | Crops |
|---|---|
| Rice | Rice (Palay) |
| Corn | Corn (Mais) |
| Vegetables | Tomato, Eggplant, Ampalaya, Sitaw, Okra, Cabbage, Chili, Cucumber, Squash |
| Allium | Onion, Garlic |
| Root | Cassava, Sweet potato, Peanut |
| Banana | Banana Saba |

## Curated series catalog (v1)

| Code | Label | Typical texture | Short farmer hint |
|---|---|---|---|
| `bantog` | Bantog | `clay_loam` | Sticky clay loam; slow drainage; crack when dry |
| `maligaya` | Maligaya | `clay` | Heavy clay; very slow drainage |
| `bigaa` | Bigaa | `clay` | Firm clayey; hard when dry |
| `san_manuel` | San Manuel | `loam` | Friable loam family; good for many crops |
| `quingua` | Quingua | `loam` | Medium / loamy terraces; flexible rice + cash crops |
| `umingan` | Umingan | `sandy_loam` | Gravelly subsoil; flood / drought risk |
| `san_fernando` | San Fernando | `clay_loam` | Clay–loam; strong for irrigated rice / maize (Ilocos lit.) |
| `angeles` | Angeles | `sandy` | Coarse sand; drains fast; low fertility |
| `obando` | Obando | `sandy_loam` | Sandy loam; low water-holding |

Plus UX-only: **Skip / Hindi ko sure** (null) and **Other** (`other` + free text — **no** series score).

## Per-series crop fit (preferred / acceptable / caution)

Legend: **P** preferred · **A** acceptable · **C** caution. Blank = treat as **C** for score simplicity when series chosen.

### Bantog (`clay_loam`)
PhilRice: suited irrigated/rainfed paddy; diversified needs drainage / beds; root S1 in Nueva Ecija table; Bantog rice-based paper: rice highly suitable, other crops moderate–high with drainage mgmt. Ilocos: often S1 across many crops.

| Crop group | Fit | Notes |
|---|---|---|
| Rice | P | Core series for lowland rice |
| Corn | A | Possible with drainage / timing |
| Vegetables | A | Broadbeds, ridges, mulch |
| Allium | A | Drainage critical |
| Root | P | NE root table S1 (camote); cassava/peanut group proxy |
| Banana | A | Needs drainage management |

### Maligaya (`clay`)
PhilRice NE: heavy clay, very slow permeability; rice suited; diversified needs drainage + OM; root S2f (camote). Muñoz GIS: clay/clay loam texture limits corn vs loam.

| Crop group | Fit |
|---|---|
| Rice | P |
| Corn | C |
| Vegetables | C |
| Allium | C |
| Root | A |
| Banana | C |

### Bigaa (`clay`)
PhilRice Bulacan: suitable for rice (clayey); diversified with beds; **not suitable for rootcrops** (texture).

| Crop group | Fit |
|---|---|
| Rice | P |
| Corn | C |
| Vegetables | A |
| Allium | C |
| Root | C |
| Banana | C |

### San Manuel (`loam`)
PhilRice: paddy wet season; diversified corn/vegetables/watermelon dry season; root S1 (NE camote). Ilocos: S1 garlic, irrigated rice, maize, onion, tomato. Agusan: highly suitable corn, vegetables, root, banana.

| Crop group | Fit |
|---|---|
| Rice | P |
| Corn | P |
| Vegetables | P |
| Allium | P |
| Root | P |
| Banana | P |

### Quingua (`loam`)
PhilRice: paddy + diversified + root suited. Quingua rice-based paper: high flexibility for multiple crops with OM/drainage/flood management. Zambales diversified table: onion N2 / tomato S3 in that province — still encode national **typical** as preferred for veg/allium with honesty that local flood/climate can limit.

| Crop group | Fit |
|---|---|
| Rice | P |
| Corn | P |
| Vegetables | P |
| Allium | A |
| Root | P |
| Banana | A |

### Umingan (`sandy_loam`)
PhilRice: paddy/other with fert; diversified suited; gravelly subsoil may **lower root yields**; flood after heavy rain.

| Crop group | Fit |
|---|---|
| Rice | A |
| Corn | A |
| Vegetables | A |
| Allium | A |
| Root | C |
| Banana | A |

### San Fernando (`clay_loam`)
Ilocos Norte FAO assessment: S1 irrigated rice and maize. Texture clay–loam dominant in study pedons.

| Crop group | Fit |
|---|---|
| Rice | P |
| Corn | P |
| Vegetables | A |
| Allium | A |
| Root | A |
| Banana | A |

### Angeles (`sandy`)
PhilRice: coarse sand, rapid permeability, low fertility. Zambales diversified: onion N2, tomato N1 for Angeles. Root possible only with irrigation / OM (proxy acceptable).

| Crop group | Fit |
|---|---|
| Rice | C |
| Corn | C |
| Vegetables | C |
| Allium | C |
| Root | A |
| Banana | C |

### Obando (`sandy_loam`)
PhilRice Bulacan: sandy loam, low WHC; rice wet with fert; **suitable for root crops** due to sandy texture; diversified with OM / timing.

| Crop group | Fit |
|---|---|
| Rice | A |
| Corn | A |
| Vegetables | A |
| Allium | A |
| Root | P |
| Banana | A |

## Expand groups → 17 crop names (implementer table)

For each series, assign every SoilGood crop the fit of its group (Allium separate from Vegetables). Code: `lib/features/crops/data/crop_series_fit.dart`.

## Schema (Option A)

**Farms (per farmer):**
- `soil_texture` — required for onboarding gate (existing)
- `soil_series` — nullable curated code or `other`
- `soil_series_other` — nullable free text when `other`

**Catalog:** Dart (and this doc) — `code`, `label`, `typical_texture`, hints. No need to stamp typical feel onto `farms`.

SQL migration: [`supabase_farm_soil_series.sql`](supabase_farm_soil_series.sql).

## Key sources

1. PhilRice Soils Information System (PSIS) — province property + suitability tables (Nueva Ecija, Bulacan, Pangasinan, Zambales, Ilocos).  
2. PhilRice Simplified Keys to Soil Series (province booklets).  
3. Collado et al. — Bantog series rice-based suitability (Philippine Journal of Science).  
4. Quingua series rice-based farming evaluation (IJEC).  
5. Ilocos Norte soil series characterization / FAO suitability (MJST).  
6. Agusan del Sur provincial soil series crop notes.  
7. Capiz major soil series paper — local acidity caveat.

## Related

- Texture research: [`SOIL_TEXTURE_CROP_FIT.md`](SOIL_TEXTURE_CROP_FIT.md)  
- Future NCCAG: [`FUTURE_ENHANCEMENTS_SOIL.md`](FUTURE_ENHANCEMENTS_SOIL.md)  
- Onboarding: [`../pages/onboarding.md`](../pages/onboarding.md)
