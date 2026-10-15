-- SoilGood — optional farm soil series (BSWM/PhilRice curated codes)
-- Run after supabase_farm_soil_texture.sql.
-- Safe to re-run. Catalog + typical feel live in app docs/Dart (Option A).

alter table public.farms
  add column if not exists soil_series text;

alter table public.farms
  add column if not exists soil_series_other text;

alter table public.farms
  drop constraint if exists farms_soil_series_check;

alter table public.farms
  add constraint farms_soil_series_check
  check (
    soil_series is null
    or soil_series in (
      'bantog',
      'maligaya',
      'bigaa',
      'san_manuel',
      'quingua',
      'umingan',
      'san_fernando',
      'angeles',
      'obando',
      'other'
    )
  );

comment on column public.farms.soil_series is
  'Optional curated BSWM/PhilRice series code, or other. null = skip. Typical feel is catalog-only.';

comment on column public.farms.soil_series_other is
  'Free-text series name when soil_series = other. Not used in match scoring.';
