-- SoilGood — initial schema for Supabase
-- Paste into: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run? Partially — uses IF NOT EXISTS; policies are dropped/recreated.
--
-- IMPORTANT: If project was created with "Automatically expose new tables" OFF,
-- also run supabase_grants.sql after this (or the grants block at the end of this file).

-- Extensions
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  barangay text not null default '',
  municipality_city text not null default '',
  province text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Auto-create profile when a user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- farms
-- ---------------------------------------------------------------------------
create table if not exists public.farms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  barangay text not null default '',
  municipality_city text not null default '',
  province text not null default '',
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create index if not exists farms_owner_id_idx on public.farms (owner_id);

-- ---------------------------------------------------------------------------
-- devices (ESP32 — claimed by device_uid)
-- ---------------------------------------------------------------------------
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  device_uid text not null unique,
  ingest_token text,
  name text not null default 'SoilGood Sensor',
  status text not null default 'unclaimed'
    check (status in ('unclaimed', 'active', 'offline', 'error')),
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists devices_farm_id_idx on public.devices (farm_id);

-- ---------------------------------------------------------------------------
-- soil_readings
-- ---------------------------------------------------------------------------
create table if not exists public.soil_readings (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  recorded_at timestamptz not null default now(),
  moisture_percent double precision,
  ph double precision,
  soil_temperature_c double precision,
  ec double precision,
  salinity double precision,
  nitrogen double precision,
  phosphorus double precision,
  potassium double precision,
  validation_status text not null default 'ok'
    check (validation_status in ('ok', 'warning', 'error')),
  validation_message text
);

-- Existing projects: add salinity if the table was created before 8-in-1.
alter table public.soil_readings
  add column if not exists salinity double precision;

create index if not exists soil_readings_device_id_recorded_at_idx
  on public.soil_readings (device_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- weather_snapshots
-- ---------------------------------------------------------------------------
create table if not exists public.weather_snapshots (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  recorded_at timestamptz not null default now(),
  temperature_c double precision,
  humidity_percent double precision,
  rainfall_mm double precision,
  rain_probability double precision,
  wind_speed double precision,
  weather_condition text,
  source text not null default 'unknown'
);

create index if not exists weather_snapshots_farm_id_recorded_at_idx
  on public.weather_snapshots (farm_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- crops (reference data — curated in DB, not from live internet APIs)
-- ---------------------------------------------------------------------------
create table if not exists public.crops (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  moisture_min double precision,
  moisture_max double precision,
  ph_min double precision,
  ph_max double precision,
  temperature_min_c double precision,
  temperature_max_c double precision,
  ec_min double precision,
  ec_max double precision,
  nitrogen_min double precision,
  nitrogen_max double precision,
  phosphorus_min double precision,
  phosphorus_max double precision,
  potassium_min double precision,
  potassium_max double precision,
  salinity_min double precision,
  salinity_max double precision,
  growing_season text,
  notes text
);

-- ---------------------------------------------------------------------------
-- plantings
-- ---------------------------------------------------------------------------
create table if not exists public.plantings (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  crop_id uuid not null references public.crops (id),
  planted_at date,
  expected_harvest_at date,
  status text not null default 'active'
    check (status in ('planned', 'active', 'harvested', 'failed')),
  created_at timestamptz not null default now()
);

create index if not exists plantings_farm_id_idx on public.plantings (farm_id);

-- ---------------------------------------------------------------------------
-- ai_assessments
-- ---------------------------------------------------------------------------
create table if not exists public.ai_assessments (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  soil_reading_id uuid references public.soil_readings (id) on delete set null,
  weather_snapshot_id uuid references public.weather_snapshots (id) on delete set null,
  overview text not null default '',
  soil_health_score double precision,
  generated_at timestamptz not null default now(),
  model_name text,
  prompt_version text
);

create index if not exists ai_assessments_farm_id_generated_at_idx
  on public.ai_assessments (farm_id, generated_at desc);

-- ---------------------------------------------------------------------------
-- ai_recommendations
-- ---------------------------------------------------------------------------
create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.ai_assessments (id) on delete cascade,
  type text not null
    check (type in ('irrigation', 'nutrient', 'soil_management', 'crop_suitability')),
  title text not null,
  description text not null default '',
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high')),
  recommended_action text not null default '',
  valid_until timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists ai_recommendations_assessment_id_idx
  on public.ai_recommendations (assessment_id);

-- ---------------------------------------------------------------------------
-- farm_actions (what the farmer actually did)
-- ---------------------------------------------------------------------------
create table if not exists public.farm_actions (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  created_by uuid not null references public.profiles (id),
  action_type text not null
    check (action_type in ('irrigation', 'fertilizer', 'planting', 'treatment')),
  amount double precision,
  unit text,
  notes text,
  performed_at timestamptz not null default now()
);

create index if not exists farm_actions_farm_id_performed_at_idx
  on public.farm_actions (farm_id, performed_at desc);

-- ---------------------------------------------------------------------------
-- Helper: does current user own this farm?
-- ---------------------------------------------------------------------------
create or replace function public.user_owns_farm(p_farm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.farms f
    where f.id = p_farm_id
      and f.owner_id = auth.uid()
  );
$$;

create or replace function public.user_owns_device(p_device_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.devices d
    join public.farms f on f.id = d.farm_id
    where d.id = p_device_id
      and f.owner_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.farms enable row level security;
alter table public.devices enable row level security;
alter table public.soil_readings enable row level security;
alter table public.weather_snapshots enable row level security;
alter table public.crops enable row level security;
alter table public.plantings enable row level security;
alter table public.ai_assessments enable row level security;
alter table public.ai_recommendations enable row level security;
alter table public.farm_actions enable row level security;

-- profiles
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- farms
drop policy if exists "farms_select_own" on public.farms;
drop policy if exists "farms_insert_own" on public.farms;
drop policy if exists "farms_update_own" on public.farms;
drop policy if exists "farms_delete_own" on public.farms;
create policy "farms_select_own" on public.farms
  for select using (owner_id = auth.uid());
create policy "farms_insert_own" on public.farms
  for insert with check (owner_id = auth.uid());
create policy "farms_update_own" on public.farms
  for update using (owner_id = auth.uid());
create policy "farms_delete_own" on public.farms
  for delete using (owner_id = auth.uid());

-- devices
drop policy if exists "devices_select_own" on public.devices;
drop policy if exists "devices_insert_own" on public.devices;
drop policy if exists "devices_update_own" on public.devices;
drop policy if exists "devices_delete_own" on public.devices;
create policy "devices_select_own" on public.devices
  for select using (public.user_owns_farm(farm_id));
create policy "devices_insert_own" on public.devices
  for insert with check (public.user_owns_farm(farm_id));
create policy "devices_update_own" on public.devices
  for update using (public.user_owns_farm(farm_id));
create policy "devices_delete_own" on public.devices
  for delete using (public.user_owns_farm(farm_id));

-- soil_readings
drop policy if exists "soil_readings_select_own" on public.soil_readings;
drop policy if exists "soil_readings_insert_own" on public.soil_readings;
create policy "soil_readings_select_own" on public.soil_readings
  for select using (public.user_owns_device(device_id));
-- App/user can insert mock readings while developing without ESP32
create policy "soil_readings_insert_own" on public.soil_readings
  for insert with check (public.user_owns_device(device_id));

-- weather_snapshots
drop policy if exists "weather_select_own" on public.weather_snapshots;
drop policy if exists "weather_insert_own" on public.weather_snapshots;
create policy "weather_select_own" on public.weather_snapshots
  for select using (public.user_owns_farm(farm_id));
create policy "weather_insert_own" on public.weather_snapshots
  for insert with check (public.user_owns_farm(farm_id));

-- crops: readable by any authenticated user; writes via dashboard/SQL for now
drop policy if exists "crops_select_authenticated" on public.crops;
create policy "crops_select_authenticated" on public.crops
  for select to authenticated using (true);

-- plantings
drop policy if exists "plantings_select_own" on public.plantings;
drop policy if exists "plantings_insert_own" on public.plantings;
drop policy if exists "plantings_update_own" on public.plantings;
drop policy if exists "plantings_delete_own" on public.plantings;
create policy "plantings_select_own" on public.plantings
  for select using (public.user_owns_farm(farm_id));
create policy "plantings_insert_own" on public.plantings
  for insert with check (public.user_owns_farm(farm_id));
create policy "plantings_update_own" on public.plantings
  for update using (public.user_owns_farm(farm_id));
create policy "plantings_delete_own" on public.plantings
  for delete using (public.user_owns_farm(farm_id));

-- ai_assessments
drop policy if exists "ai_assessments_select_own" on public.ai_assessments;
drop policy if exists "ai_assessments_insert_own" on public.ai_assessments;
create policy "ai_assessments_select_own" on public.ai_assessments
  for select using (public.user_owns_farm(farm_id));
create policy "ai_assessments_insert_own" on public.ai_assessments
  for insert with check (public.user_owns_farm(farm_id));

-- ai_recommendations (via assessment ownership)
drop policy if exists "ai_recommendations_select_own" on public.ai_recommendations;
drop policy if exists "ai_recommendations_insert_own" on public.ai_recommendations;
create policy "ai_recommendations_select_own" on public.ai_recommendations
  for select using (
    exists (
      select 1
      from public.ai_assessments a
      where a.id = assessment_id
        and public.user_owns_farm(a.farm_id)
    )
  );
create policy "ai_recommendations_insert_own" on public.ai_recommendations
  for insert with check (
    exists (
      select 1
      from public.ai_assessments a
      where a.id = assessment_id
        and public.user_owns_farm(a.farm_id)
    )
  );

-- farm_actions
drop policy if exists "farm_actions_select_own" on public.farm_actions;
drop policy if exists "farm_actions_insert_own" on public.farm_actions;
create policy "farm_actions_select_own" on public.farm_actions
  for select using (public.user_owns_farm(farm_id));
create policy "farm_actions_insert_own" on public.farm_actions
  for insert with check (
    public.user_owns_farm(farm_id)
    and created_by = auth.uid()
  );

-- ---------------------------------------------------------------------------
-- Realtime (soil readings live updates)
-- ---------------------------------------------------------------------------
-- In Dashboard: Database → Replication → enable for soil_readings
-- Or run (may error if already added — safe to ignore):
-- alter publication supabase_realtime add table public.soil_readings;

-- ---------------------------------------------------------------------------
-- Optional starter crops (placeholder ranges — refine with agri sources later)
-- ---------------------------------------------------------------------------
insert into public.crops (
  name,
  moisture_min, moisture_max,
  ph_min, ph_max,
  temperature_min_c, temperature_max_c,
  growing_season, notes
)
values
  ('Rice (Palay)', 60, 90, 5.5, 7.0, 20, 35, 'Wet season', 'Placeholder ranges — replace with verified source'),
  ('Corn (Mais)', 50, 80, 5.8, 7.0, 18, 32, 'Dry/wet depending on variety', 'Placeholder ranges'),
  ('Tomato', 60, 80, 6.0, 6.8, 18, 30, 'Year-round with care', 'Placeholder ranges')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Grants (required when "Automatically expose new tables" is OFF)
-- RLS still filters rows; without GRANT, PostgREST returns permission denied.
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated;

grant select, update on table public.profiles to authenticated;

grant select, insert, update, delete on table public.farms to authenticated;
grant select, insert, update, delete on table public.devices to authenticated;
grant select, insert on table public.soil_readings to authenticated;
grant select, insert on table public.weather_snapshots to authenticated;
grant select on table public.crops to authenticated;
grant select, insert, update, delete on table public.plantings to authenticated;
grant select, insert on table public.ai_assessments to authenticated;
grant select, insert on table public.ai_recommendations to authenticated;
grant select, insert on table public.farm_actions to authenticated;

-- ESP32 heartbeat / readings: run supabase_esp32_ingest.sql after this file
-- (RPC ingest_soil_reading for anon key + ingest_token; never service_role on device).
-- Analytics daily buckets + period_days: run supabase_analytics.sql.
-- Crops phases + ai_assessments.kind (home/analytics/crops): run supabase_crops_home_ai.sql.
-- Farm alert rows (inbox later): run supabase_notifications.sql.

