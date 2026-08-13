  -- SoilGood — Analytics history RPC + period AI window columns
  -- Run in Supabase SQL Editor after supabase_schema.sql.
  -- Safe to re-run.
  --
  -- Daily buckets avoid pulling ~2,880 raw 15-min rows (PostgREST default cap 1000).
  -- Days are Asia/Manila (no DST). security invoker so RLS still applies.
  -- Period AI is keyed by period_start + period_end (the selected Analytics window).

  alter table public.ai_assessments
    add column if not exists period_days int;

  alter table public.ai_assessments
    add column if not exists period_start date;

  alter table public.ai_assessments
    add column if not exists period_end date;

  alter table public.ai_assessments
    drop constraint if exists ai_assessments_period_days_check;

  alter table public.ai_assessments
    add constraint ai_assessments_period_days_check
    check (period_days is null or period_days >= 1);

  create index if not exists ai_assessments_farm_period_generated_idx
    on public.ai_assessments (farm_id, period_days, generated_at desc);

  create index if not exists ai_assessments_farm_kind_window_idx
    on public.ai_assessments (farm_id, kind, period_start, period_end, generated_at desc);

  drop function if exists public.analytics_soil_daily(timestamptz, timestamptz);

  create or replace function public.analytics_soil_daily(
    p_from timestamptz,
    p_to timestamptz
  )
  returns table (
    bucket_date date,
    avg_moisture double precision,
    min_moisture double precision,
    max_moisture double precision,
    avg_ph double precision,
    min_ph double precision,
    max_ph double precision,
    avg_temp double precision,
    min_temp double precision,
    max_temp double precision,
    avg_ec double precision,
    min_ec double precision,
    max_ec double precision,
    avg_salinity double precision,
    min_salinity double precision,
    max_salinity double precision,
    avg_nitrogen double precision,
    min_nitrogen double precision,
    max_nitrogen double precision,
    avg_phosphorus double precision,
    min_phosphorus double precision,
    max_phosphorus double precision,
    avg_potassium double precision,
    min_potassium double precision,
    max_potassium double precision,
    reading_count bigint
  )
  language sql
  stable
  security invoker
  set search_path = public
  as $$
    select
      (timezone('Asia/Manila', sr.recorded_at))::date as bucket_date,
      avg(sr.moisture_percent),
      min(sr.moisture_percent),
      max(sr.moisture_percent),
      avg(sr.ph),
      min(sr.ph),
      max(sr.ph),
      avg(sr.soil_temperature_c),
      min(sr.soil_temperature_c),
      max(sr.soil_temperature_c),
      avg(sr.ec),
      min(sr.ec),
      max(sr.ec),
      avg(sr.salinity),
      min(sr.salinity),
      max(sr.salinity),
      avg(sr.nitrogen),
      min(sr.nitrogen),
      max(sr.nitrogen),
      avg(sr.phosphorus),
      min(sr.phosphorus),
      max(sr.phosphorus),
      avg(sr.potassium),
      min(sr.potassium),
      max(sr.potassium),
      count(*)::bigint
    from public.soil_readings sr
    join public.devices d on d.id = sr.device_id
    join public.farms f on f.id = d.farm_id
    where f.owner_id = auth.uid()
      and sr.recorded_at >= p_from
      and sr.recorded_at < p_to
    group by 1
    order by 1;
  $$;

  grant execute on function public.analytics_soil_daily(timestamptz, timestamptz)
    to authenticated;

  revoke execute on function public.analytics_soil_daily(timestamptz, timestamptz)
    from anon, public;
