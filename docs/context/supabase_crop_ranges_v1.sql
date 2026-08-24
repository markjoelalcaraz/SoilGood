-- SoilGood — Crop ranges v1 (17 PH crops + phases + range_meta)
-- Run after supabase_schema.sql and supabase_crops_home_ai.sql.
-- Safe to re-run. Source of truth for numbers: docs/context/CROP_RANGES.md
-- NPK columns are cleared (null) → Flutter uses insights.json universal low-only.

alter table public.crops
  add column if not exists range_meta jsonb;

-- ---------------------------------------------------------------------------
-- Refresh Rice / Corn / Tomato
-- ---------------------------------------------------------------------------
update public.crops
set
  scientific_name = 'Oryza sativa',
  days_to_maturity = 110,
  moisture_min = 60, moisture_max = 100,
  ph_min = 5.5, ph_max = 7.0,
  temperature_min_c = 20, temperature_max_c = 35,
  ec_min = 0.2, ec_max = 3.0,
  salinity_min = 0, salinity_max = 1.9,
  nitrogen_min = null, nitrogen_max = null,
  phosphorus_min = null, phosphorus_max = null,
  potassium_min = null, potassium_max = null,
  growing_season = 'Wet season',
  notes = 'Mapped moisture class A (paddy). Temp PhilRice 20–35°C. EC FAO ECe 3.0.',
  range_meta = '{
    "moisture_basis":"mapped_v1","hydro_class":"A",
    "temp_source":"philrice","ph_source":"phil_lit",
    "ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece",
    "npk_basis":"universal_low_only","clock":"DAT"
  }'::jsonb,
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative / tillering","days":31},
    {"id":"reproductive","label":"Reproductive","days":35},
    {"id":"ripening","label":"Ripening / harvest","days":30}
  ]'::jsonb
where name = 'Rice (Palay)';

update public.crops
set
  scientific_name = 'Zea mays',
  days_to_maturity = 100,
  moisture_min = 40, moisture_max = 75,
  ph_min = 5.5, ph_max = 7.0,
  temperature_min_c = 18, temperature_max_c = 32,
  ec_min = 0.2, ec_max = 1.7,
  salinity_min = 0, salinity_max = 1.1,
  nitrogen_min = null, nitrogen_max = null,
  phosphorus_min = null, phosphorus_max = null,
  potassium_min = null, potassium_max = null,
  growing_season = 'Dry/wet depending on variety',
  notes = 'Mapped moisture class C. EC FAO ECe 1.7. Silk stage water/heat critical.',
  range_meta = '{
    "moisture_basis":"mapped_v1","hydro_class":"C",
    "temp_source":"da_fao","ph_source":"da_rfo2",
    "ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece",
    "npk_basis":"universal_low_only","clock":"DAP"
  }'::jsonb,
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative growth","days":36},
    {"id":"reproductive","label":"Tassel / silk","days":20},
    {"id":"grain_fill","label":"Grain fill / harvest","days":30}
  ]'::jsonb
where name = 'Corn (Mais)';

update public.crops
set
  scientific_name = 'Solanum lycopersicum',
  days_to_maturity = 90,
  moisture_min = 40, moisture_max = 70,
  ph_min = 5.5, ph_max = 8.0,
  temperature_min_c = 18, temperature_max_c = 30,
  ec_min = 0.2, ec_max = 2.5,
  salinity_min = 0, salinity_max = 1.6,
  nitrogen_min = null, nitrogen_max = null,
  phosphorus_min = null, phosphorus_max = null,
  potassium_min = null, potassium_max = null,
  growing_season = 'Year-round with care',
  notes = 'Mapped moisture class C (tighter wet). ATI opt air ~21–24°C; catalog 18–30 for PH field. EC FAO 2.5.',
  range_meta = '{
    "moisture_basis":"mapped_v1","hydro_class":"C",
    "temp_source":"ati_opt_wider","temp_opt_c":[21,24],
    "ph_source":"ati","ec_basis":"fao_ece_v1",
    "salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"
  }'::jsonb,
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative growth","days":21},
    {"id":"flowering_fruiting","label":"Flowering / fruiting","days":25},
    {"id":"harvest","label":"Harvest","days":30}
  ]'::jsonb
where name = 'Tomato';

-- ---------------------------------------------------------------------------
-- Insert / upsert 14 new crops
-- ---------------------------------------------------------------------------
insert into public.crops (
  name, scientific_name, days_to_maturity,
  moisture_min, moisture_max, ph_min, ph_max,
  temperature_min_c, temperature_max_c,
  ec_min, ec_max, salinity_min, salinity_max,
  growing_season, notes, range_meta, phases
) values
(
  'Eggplant (Talong)', 'Solanum melongena', 90,
  40, 75, 5.5, 6.8, 21, 30, 0.2, 1.1, 0, 0.7,
  'Year-round with care',
  'DA pH/temp. EC FAO ECe 1.1. Moisture class C.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"da","ph_source":"da","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vegetative growth","days":16},{"id":"flowering_fruiting","label":"Flowering / fruiting","days":20},{"id":"harvest","label":"Harvest","days":40}]'::jsonb
),
(
  'Ampalaya', 'Momordica charantia', 70,
  40, 75, 6.0, 6.7, 22, 32, 0.2, 2.5, 0, 1.6,
  'Best Oct–Feb',
  'DA pH 6.0–6.7. Temp inferred tropical. EC proxy_cucumber 2.5.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"inferred_tropical","ph_source":"da_rfo2","ec_basis":"proxy_cucumber","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vegetative / trellis","days":16},{"id":"flowering_fruiting","label":"Flowering / fruiting","days":20},{"id":"harvest","label":"Harvest","days":20}]'::jsonb
),
(
  'Sitaw', 'Vigna unguiculata', 60,
  40, 75, 5.5, 6.8, 20, 35, 0.2, 4.9, 0, 3.1,
  'Year-round',
  'ATI pH/temp. EC cowpea FAO 4.9. Moisture class C.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"ati","ph_source":"ati","ec_basis":"fao_ece_v1","ec_note":"cowpea_seed","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Emergence","days":10},{"id":"vegetative","label":"Vegetative / trellis","days":20},{"id":"flowering_fruiting","label":"Flowering / pods","days":15},{"id":"harvest","label":"Harvest","days":15}]'::jsonb
),
(
  'Okra', 'Abelmoschus esculentus', 70,
  40, 75, 5.5, 7.0, 20, 30, 0.2, 2.0, 0, 1.3,
  'Warm season',
  'DA temp 20–30°C. EC universal (FAO MS no number).',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"da_rfo2","ph_source":"ph_okra_guides","ec_basis":"universal","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Emergence","days":10},{"id":"vegetative","label":"Vegetative growth","days":25},{"id":"flowering_fruiting","label":"Flowering","days":15},{"id":"harvest","label":"Harvest","days":20}]'::jsonb
),
(
  'Cabbage (Repolyo)', 'Brassica oleracea var. capitata', 58,
  45, 80, 6.0, 6.8, 15, 20, 0.2, 1.8, 0, 1.2,
  'Cool months / highland',
  'DA cool crop. EC FAO 1.8. Minimize water at heading.',
  '{"moisture_basis":"mapped_v1","hydro_class":"B","temp_source":"da_rfo2","ph_source":"da_rfo2","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Leafy growth","days":21},{"id":"heading","label":"Head formation","days":16},{"id":"harvest","label":"Harvest","days":7}]'::jsonb
),
(
  'Onion (Sibuyas)', 'Allium cepa', 110,
  35, 70, 5.8, 6.0, 15, 30, 0.2, 1.2, 0, 0.8,
  'Cool early; dry for bulbs',
  'DA pH 5.8–6. Hydro class E. EC FAO 1.2. Stop water 3–5 d before harvest.',
  '{"moisture_basis":"mapped_v1","hydro_class":"E","temp_source":"da_qualitative","ph_source":"da_rfo2","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Leaf growth","days":36},{"id":"bulb_swell","label":"Bulb development","days":50},{"id":"dry_down","label":"Dry-down / harvest","days":10}]'::jsonb
),
(
  'Garlic (Bawang)', 'Allium sativum', 105,
  35, 70, 5.8, 6.0, 15, 30, 0.2, 3.9, 0, 2.5,
  'Cool early; dry ripening',
  'pH proxy_onion. EC FAO garlic 3.9. End irrigation ~70–85 DAP (BPI).',
  '{"moisture_basis":"mapped_v1","hydro_class":"E","temp_source":"bpi","ph_source":"proxy_onion","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vegetative","days":36},{"id":"bulb_swell","label":"Bulbing","days":40},{"id":"ripening","label":"Ripening / harvest","days":15}]'::jsonb
),
(
  'Chili (Sili)', 'Capsicum annuum', 85,
  40, 75, 5.5, 6.5, 20, 30, 0.2, 1.5, 0, 1.0,
  'Dry or wet season with drainage',
  'Hot pepper / sili (not sweet pepper). EC FAO pepper 1.5.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"da_pepper","ph_source":"pinoyrice_da","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAT"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vegetative growth","days":21},{"id":"flowering_fruiting","label":"Flowering / fruiting","days":30},{"id":"harvest","label":"Harvest","days":20}]'::jsonb
),
(
  'Cucumber (Pipino)', 'Cucumis sativus', 70,
  40, 75, 6.5, 7.5, 18, 30, 0.2, 2.5, 0, 1.6,
  'Warm season',
  'DA night 18–20 / day ~30°C. EC FAO 2.5.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"da_rfo2","ph_source":"da_rfo2","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Emergence","days":10},{"id":"vegetative","label":"Vegetative growth","days":18},{"id":"flowering_fruiting","label":"Flowering / fruiting","days":14},{"id":"harvest","label":"Harvest","days":28}]'::jsonb
),
(
  'Squash (Kalabasa)', 'Cucurbita maxima', 85,
  40, 75, 5.5, 6.5, 18, 30, 0.2, 3.2, 0, 2.0,
  'Dry-warm helps fruit set',
  'DA pH/temp. EC proxy_scallop_squash 3.2.',
  '{"moisture_basis":"mapped_v1","hydro_class":"C","temp_source":"da_rfo2","ph_source":"da_rfo2","ec_basis":"proxy_scallop_squash","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vine growth","days":21},{"id":"flowering_fruiting","label":"Flowering","days":25},{"id":"fruit_fill","label":"Fruit fill / harvest","days":25}]'::jsonb
),
(
  'Peanut (Mani)', 'Arachis hypogaea', 100,
  30, 65, 5.8, 6.5, 20, 30, 0.2, 3.2, 0, 2.0,
  'Often dry season for quality',
  'Critical water at flower/peg/pod. EC FAO 3.2. Moisture class D.',
  '{"moisture_basis":"mapped_v1","hydro_class":"D","temp_source":"ph_peanut_tech","ph_source":"ph_peanut_tech","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Emergence","days":14},{"id":"vegetative","label":"Vegetative","days":21},{"id":"flowering_pegging","label":"Flowering / pegging","days":30},{"id":"pod_fill","label":"Pod fill / harvest","days":35}]'::jsonb
),
(
  'Cassava (Kamoteng kahoy)', 'Manihot esculenta', 270,
  30, 65, 4.4, 7.5, 25, 30, 0.2, 2.0, 0, 1.3,
  'Plant on rains; drought-tolerant later',
  'IDRC acid-tolerant. EC universal. No flooding. Moisture class D.',
  '{"moisture_basis":"mapped_v1","hydro_class":"D","temp_source":"idrc_ph","ph_source":"idrc","ec_basis":"universal","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":30},{"id":"vegetative","label":"Canopy","days":60},{"id":"root_bulk","label":"Root bulking","days":150},{"id":"harvest","label":"Harvest window","days":30}]'::jsonb
),
(
  'Sweet potato (Kamote)', 'Ipomoea batatas', 110,
  30, 65, 5.5, 6.5, 25, 30, 0.2, 1.5, 0, 1.0,
  '3–4 months',
  'DA pH/temp. EC FAO 1.5. Hate prolonged waterlog.',
  '{"moisture_basis":"mapped_v1","hydro_class":"D","temp_source":"da_rfo2","ph_source":"da_rfo2","ec_basis":"fao_ece_v1","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":14},{"id":"vegetative","label":"Vine growth","days":21},{"id":"tuber_init","label":"Tuber initiation","days":30},{"id":"tuber_bulk","label":"Bulking / harvest","days":45}]'::jsonb
),
(
  'Banana (Saba)', 'Musa acuminata × balbisiana', 450,
  45, 80, 4.5, 7.5, 27, 30, 0.2, 1.0, 0, 0.6,
  'Warm humid; irrigate long dry',
  'DA Saba climate. EC fao_sensitive_class ~1.0. Moisture class B.',
  '{"moisture_basis":"mapped_v1","hydro_class":"B","temp_source":"da_cdo_saba","ph_source":"da_cdo","ec_basis":"fao_sensitive_class","salinity_basis":"mapped_from_ece","npk_basis":"universal_low_only","clock":"DAP"}'::jsonb,
  '[{"id":"establishment","label":"Establishment","days":60},{"id":"vegetative","label":"Vegetative","days":240},{"id":"shooting","label":"Shooting / flowering","days":30},{"id":"bunch_fill","label":"Bunch fill / harvest","days":120}]'::jsonb
)
on conflict (name) do update set
  scientific_name = excluded.scientific_name,
  days_to_maturity = excluded.days_to_maturity,
  moisture_min = excluded.moisture_min,
  moisture_max = excluded.moisture_max,
  ph_min = excluded.ph_min,
  ph_max = excluded.ph_max,
  temperature_min_c = excluded.temperature_min_c,
  temperature_max_c = excluded.temperature_max_c,
  ec_min = excluded.ec_min,
  ec_max = excluded.ec_max,
  salinity_min = excluded.salinity_min,
  salinity_max = excluded.salinity_max,
  nitrogen_min = null,
  nitrogen_max = null,
  phosphorus_min = null,
  phosphorus_max = null,
  potassium_min = null,
  potassium_max = null,
  growing_season = excluded.growing_season,
  notes = excluded.notes,
  range_meta = excluded.range_meta,
  phases = excluded.phases;
