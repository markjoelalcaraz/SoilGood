-- SoilGood — Crops catalog phases + AI assessment kind (Home / Analytics / Crops)
-- Run in Supabase SQL Editor after supabase_schema.sql and supabase_analytics.sql.
-- Safe to re-run.
-- After this file, run supabase_crop_ranges_v1.sql for the 17-crop researched baselines.

-- ---------------------------------------------------------------------------
-- crops: duration + cultivation phases (local timeline, not Groq)
-- ---------------------------------------------------------------------------
alter table public.crops
  add column if not exists scientific_name text;

alter table public.crops
  add column if not exists days_to_maturity int;

alter table public.crops
  add column if not exists phases jsonb;

alter table public.crops
  add column if not exists salinity_min double precision;

alter table public.crops
  add column if not exists salinity_max double precision;

-- Rice ~110d transplanted lowland
update public.crops
set
  scientific_name = 'Oryza sativa',
  days_to_maturity = 110,
  moisture_min = 60, moisture_max = 90,
  ph_min = 5.5, ph_max = 7.0,
  temperature_min_c = 20, temperature_max_c = 35,
  ec_min = 0, ec_max = 2.0,
  nitrogen_min = 40, nitrogen_max = 120,
  phosphorus_min = 15, phosphorus_max = 50,
  potassium_min = 70, potassium_max = 200,
  salinity_min = 0, salinity_max = 2.0,
  growing_season = 'Wet season',
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative / tillering","days":40},
    {"id":"reproductive","label":"Reproductive","days":35},
    {"id":"harvest","label":"Ripening / harvest","days":21}
  ]'::jsonb
where name = 'Rice (Palay)';

-- Corn ~95d
update public.crops
set
  scientific_name = 'Zea mays',
  days_to_maturity = 95,
  moisture_min = 50, moisture_max = 80,
  ph_min = 5.8, ph_max = 7.0,
  temperature_min_c = 18, temperature_max_c = 32,
  ec_min = 0, ec_max = 1.8,
  nitrogen_min = 50, nitrogen_max = 150,
  phosphorus_min = 20, phosphorus_max = 60,
  potassium_min = 80, potassium_max = 220,
  salinity_min = 0, salinity_max = 1.5,
  growing_season = 'Dry/wet depending on variety',
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative growth","days":35},
    {"id":"reproductive","label":"Reproductive","days":30},
    {"id":"harvest","label":"Harvest","days":16}
  ]'::jsonb
where name = 'Corn (Mais)';

-- Tomato ~80d
update public.crops
set
  scientific_name = 'Solanum lycopersicum',
  days_to_maturity = 80,
  moisture_min = 60, moisture_max = 80,
  ph_min = 6.0, ph_max = 6.8,
  temperature_min_c = 18, temperature_max_c = 30,
  ec_min = 0, ec_max = 2.5,
  nitrogen_min = 40, nitrogen_max = 110,
  phosphorus_min = 20, phosphorus_max = 55,
  potassium_min = 90, potassium_max = 250,
  salinity_min = 0, salinity_max = 2.0,
  growing_season = 'Year-round with care',
  phases = '[
    {"id":"establishment","label":"Establishment","days":14},
    {"id":"vegetative","label":"Vegetative growth","days":21},
    {"id":"fruiting","label":"Flowering / fruiting","days":30},
    {"id":"harvest","label":"Harvest","days":15}
  ]'::jsonb
where name = 'Tomato';

-- ---------------------------------------------------------------------------
-- ai_assessments: kind so Home / Analytics / Crops rows do not collide
-- ---------------------------------------------------------------------------
alter table public.ai_assessments
  add column if not exists kind text;

alter table public.ai_assessments
  add column if not exists planting_id uuid references public.plantings (id) on delete set null;

update public.ai_assessments
set kind = 'analytics'
where kind is null;

alter table public.ai_assessments
  alter column kind set default 'analytics';

alter table public.ai_assessments
  drop constraint if exists ai_assessments_kind_check;

alter table public.ai_assessments
  add constraint ai_assessments_kind_check
  check (kind in ('home', 'analytics', 'crops'));

alter table public.ai_assessments
  alter column kind set not null;

create index if not exists ai_assessments_farm_kind_generated_idx
  on public.ai_assessments (farm_id, kind, generated_at desc);

create index if not exists ai_assessments_planting_id_idx
  on public.ai_assessments (planting_id);
