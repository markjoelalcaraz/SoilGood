-- SoilGood — farm_notifications (alert inbox storage)
-- Run in Supabase SQL Editor after supabase_schema.sql.
-- Safe to re-run.
--
-- Flutter classifies soil + weather locally (insights.json bands) and inserts
-- one row per type per farm per Manila calendar day (phase_change is per
-- planting + phase id). No Groq. No service_role.

create table if not exists public.farm_notifications (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  type text not null
    check (type in (
      'irrigation',
      'nutrient_low',
      'soil_alert',
      'sensor_error',
      'device_offline',
      'phase_change'
    )),
  severity text not null
    check (severity in ('info', 'warning', 'urgent')),
  title text not null,
  body text not null,
  soil_reading_id uuid references public.soil_readings (id) on delete set null,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- Existing projects: allow cultivation-phase notices.
alter table public.farm_notifications drop constraint if exists farm_notifications_type_check;
alter table public.farm_notifications
  add constraint farm_notifications_type_check
  check (type in (
    'irrigation',
    'nutrient_low',
    'soil_alert',
    'sensor_error',
    'device_offline',
    'phase_change'
  ));

create unique index if not exists farm_notifications_farm_dedupe_uidx
  on public.farm_notifications (farm_id, dedupe_key);

create index if not exists farm_notifications_farm_created_idx
  on public.farm_notifications (farm_id, created_at desc);

alter table public.farm_notifications enable row level security;

drop policy if exists "farm_notifications_select_own" on public.farm_notifications;
drop policy if exists "farm_notifications_insert_own" on public.farm_notifications;
drop policy if exists "farm_notifications_update_own" on public.farm_notifications;

create policy "farm_notifications_select_own" on public.farm_notifications
  for select using (public.user_owns_farm(farm_id));

create policy "farm_notifications_insert_own" on public.farm_notifications
  for insert with check (public.user_owns_farm(farm_id));

-- Inbox will mark read_at; farmers cannot rewrite type/body via this policy
-- beyond rows they own (update using ownership).
create policy "farm_notifications_update_own" on public.farm_notifications
  for update using (public.user_owns_farm(farm_id));

grant select, insert, update on table public.farm_notifications to authenticated;

-- Live inbox later; ignore error if already in the publication.
do $$
begin
  alter publication supabase_realtime add table public.farm_notifications;
exception
  when duplicate_object then null;
end $$;
