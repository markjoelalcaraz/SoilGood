# SoilGood — Future enhancements: soil series & NCCAG

> **Not v1.** V1 crop suitability uses farmer-selected **soil texture** (required) plus optional curated **soil series** — research: [`SOIL_TEXTURE_CROP_FIT.md`](SOIL_TEXTURE_CROP_FIT.md), [`SOIL_SERIES_CROP_FIT.md`](SOIL_SERIES_CROP_FIT.md).  
> This file tracks **NCCAG GIS** and full province series keys for later thesis / product phases.

## Why later

- **Texture** is farmer-doable (feel-test) and enough for a third match pillar.  
- **BSWM soil series** and **NCCAG** need GIS data, licensing/access, and heavier UX — wrong to block onboarding on them.

---

## Enhancement S1 — NCCAG lookup by farm pin (future)

### What NCCAG is

The **National Color-Coded Agricultural Guide (NCCAG) Map** is a DA–AMIA decision-support tool ([amia.da.gov.ph](https://amia.da.gov.ph/national-color-coded-agricultural-guide-nccag-map/), map UI: [farmersguidemap.da.gov.ph](http://www.farmersguidemap.da.gov.ph/)).

It is a **database of map overlays** that shows which economically important crops are **naturally suitable** in an area. Layers combine:

- Soil properties / fertility  
- Elevation, slope  
- Rainfall, temperature, water availability  
- Land cover  
- Projected climate-related multi-hazards (CRVA)  
- Rice Suitability Zones (PRiSM) in newer versions  

It is **not** “texture alone.” It answers: *dito ba maganda itanim ang crop X?* using official biophysical + climate layers.

NCCAG crop groups (examples): rice, corn, banana, cassava, sweet potato, garlic/onion, legumes, vegetables, etc. — not always a 1:1 name match with SoilGood’s 17 catalog rows.

### Possible SoilGood use

1. After farm pin is saved, query suitability for catalog crops (if API / open layers become available).  
2. Show “DA guide for your pin” as a **second opinion** beside sensor + texture match.  
3. Optionally **suggest** texture or warn if farmer pick conflicts with map class (never silent overwrite).

### Blockers to solve before build

- Public API vs scrape vs static GeoTIFF tiles  
- License / attribution for DA layers  
- Offline / free-tier cost  
- Mapping SoilGood crop names → NCCAG commodity groups  

---

## Enhancement S2 — Full BSWM / PhilRice soil series keys (future)

### What is already in v1

Curated short list (Bantog, Maligaya, Bigaa, San Manuel, Quingua, Umingan, San Fernando, Angeles, Obando) + Skip/Other — optional under texture onboarding.

### What remains later

### What soil series is (full)

BSWM names Philippine soils as **series** (e.g. San Manuel, Bantog, Luisiana). PhilRice **Simplified Keys to Soil Series** and the **PhilRice Soil Information System (PSIS)** help identify series from field traits (color, texture, pH, coarse fragments, mottles at ~30–50 cm) and then suggest crop suitability / management.

### Possible SoilGood use

- Province-filtered full series list / AEW field-key flow  
- Link province → series list → crop recommendations  
- Do **not** replace simple texture enum for ordinary farmers who Skip

---

## Enhancement S3 — Sensor-assisted texture (research only)

8-in-1 probes do **not** measure % sand/silt/clay. Long-term moisture dynamics might *hint* at water-holding class, but that is speculative — not a v1 claim and weak for defense unless validated against lab texture.

---

## Related

- Texture research v1: [`SOIL_TEXTURE_CROP_FIT.md`](SOIL_TEXTURE_CROP_FIT.md)  
- Device futures: [`FUTURE_ENHANCEMENTS_DEVICES.md`](FUTURE_ENHANCEMENTS_DEVICES.md)  
- Features overview: [`FEATURES.md`](FEATURES.md)
