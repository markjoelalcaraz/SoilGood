-- SoilGood — several active crops on one farm, each with its own soil
-- Run in Supabase SQL Editor AFTER supabase_plantings_one_active.sql.
-- Safe to re-run.
--
-- Before: at most one active planting per farm; soil lived on `farms` only.
-- After:  a farm can grow several crops at once (each crop is its own plot,
--         each plot gets its own sensors via devices.planting_id).
--         The same crop cannot be active twice on one farm.
--         Each plot keeps the soil the farmer chose in Add a crop
--         (series optional; texture is the fallback, same as onboarding).

drop index if exists public.plantings_one_active_per_farm_uidx;

create unique index if not exists plantings_one_active_crop_per_farm_uidx
  on public.plantings (farm_id, crop_id)
  where status = 'active';

alter table public.plantings
  add column if not exists soil_texture text,
  add column if not exists soil_series text,
  add column if not exists soil_series_other text;

comment on column public.plantings.soil_texture is
  'Plot texture (sandy … clay, unknown). From series typical feel when a curated series is chosen.';
comment on column public.plantings.soil_series is
  'Optional curated BSWM series for this plot (null = not sure). Crop match prefers it over texture.';
