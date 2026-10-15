-- SoilGood — farm soil texture (farmer-selected, v1 crop match pillar)
-- Run on existing DBs after supabase_schema.sql.
-- Safe to re-run.

alter table public.farms
  add column if not exists soil_texture text;

alter table public.farms
  drop constraint if exists farms_soil_texture_check;

alter table public.farms
  add constraint farms_soil_texture_check
  check (
    soil_texture is null
    or soil_texture in (
      'sandy',
      'sandy_loam',
      'loam',
      'clay_loam',
      'clay',
      'unknown'
    )
  );

comment on column public.farms.soil_texture is
  'Farmer-selected USDA-style texture class for crop suitability. null = not set yet.';
