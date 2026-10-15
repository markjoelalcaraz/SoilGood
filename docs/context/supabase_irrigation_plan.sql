-- SoilGood — irrigation plans + farm_actions FKs + crop_care tip type
-- Run in Supabase SQL Editor after core schema.
-- Product: rolling 7-day horizon (not 7 waterings); Mark watered Today only.

-- ---------------------------------------------------------------------------
-- farm_actions: optional planting + plan slot link
-- ---------------------------------------------------------------------------
alter table public.farm_actions
  add column if not exists planting_id uuid references public.plantings (id) on delete set null;

alter table public.farm_actions
  add column if not exists plan_slot_id uuid;

create index if not exists farm_actions_farm_planting_performed_idx
  on public.farm_actions (farm_id, planting_id, performed_at desc);

-- ---------------------------------------------------------------------------
-- ai_recommendations: allow Home Crop care tip type
-- ---------------------------------------------------------------------------
alter table public.ai_recommendations
  drop constraint if exists ai_recommendations_type_check;

alter table public.ai_recommendations
  add constraint ai_recommendations_type_check
  check (type in (
    'irrigation',
    'nutrient',
    'soil_management',
    'crop_suitability',
    'crop_care'
  ));

-- ---------------------------------------------------------------------------
-- irrigation_plans
-- ---------------------------------------------------------------------------
create table if not exists public.irrigation_plans (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms (id) on delete cascade,
  planting_id uuid not null references public.plantings (id) on delete cascade,
  horizon_start date not null,
  horizon_days int not null default 7 check (horizon_days between 1 and 16),
  story_fingerprint text not null default '',
  overview text not null default '',
  model_name text,
  prompt_version text,
  generated_at timestamptz not null default now(),
  valid_until timestamptz
);

create index if not exists irrigation_plans_farm_planting_generated_idx
  on public.irrigation_plans (farm_id, planting_id, generated_at desc);

-- ---------------------------------------------------------------------------
-- irrigation_plan_slots
-- ---------------------------------------------------------------------------
create table if not exists public.irrigation_plan_slots (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.irrigation_plans (id) on delete cascade,
  slot_date date not null,
  -- water | check | no_water
  action text not null
    check (action in ('water', 'check', 'no_water')),
  confidence text not null default 'high'
    check (confidence in ('high', 'likely')),
  guidance text not null default '',
  reason text not null default '',
  completed_action_id uuid references public.farm_actions (id) on delete set null,
  unique (plan_id, slot_date)
);

create index if not exists irrigation_plan_slots_plan_date_idx
  on public.irrigation_plan_slots (plan_id, slot_date);

-- FK from farm_actions.plan_slot_id (deferred until slots table exists)
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'farm_actions_plan_slot_id_fkey'
  ) then
    alter table public.farm_actions
      add constraint farm_actions_plan_slot_id_fkey
      foreign key (plan_slot_id) references public.irrigation_plan_slots (id)
      on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.irrigation_plans enable row level security;
alter table public.irrigation_plan_slots enable row level security;

drop policy if exists "irrigation_plans_select_own" on public.irrigation_plans;
drop policy if exists "irrigation_plans_insert_own" on public.irrigation_plans;
drop policy if exists "irrigation_plans_update_own" on public.irrigation_plans;
drop policy if exists "irrigation_plans_delete_own" on public.irrigation_plans;

create policy "irrigation_plans_select_own" on public.irrigation_plans
  for select using (public.user_owns_farm(farm_id));
create policy "irrigation_plans_insert_own" on public.irrigation_plans
  for insert with check (public.user_owns_farm(farm_id));
create policy "irrigation_plans_update_own" on public.irrigation_plans
  for update using (public.user_owns_farm(farm_id));
create policy "irrigation_plans_delete_own" on public.irrigation_plans
  for delete using (public.user_owns_farm(farm_id));

drop policy if exists "irrigation_plan_slots_select_own" on public.irrigation_plan_slots;
drop policy if exists "irrigation_plan_slots_insert_own" on public.irrigation_plan_slots;
drop policy if exists "irrigation_plan_slots_update_own" on public.irrigation_plan_slots;
drop policy if exists "irrigation_plan_slots_delete_own" on public.irrigation_plan_slots;

create policy "irrigation_plan_slots_select_own" on public.irrigation_plan_slots
  for select using (
    exists (
      select 1 from public.irrigation_plans p
      where p.id = plan_id and public.user_owns_farm(p.farm_id)
    )
  );
create policy "irrigation_plan_slots_insert_own" on public.irrigation_plan_slots
  for insert with check (
    exists (
      select 1 from public.irrigation_plans p
      where p.id = plan_id and public.user_owns_farm(p.farm_id)
    )
  );
create policy "irrigation_plan_slots_update_own" on public.irrigation_plan_slots
  for update using (
    exists (
      select 1 from public.irrigation_plans p
      where p.id = plan_id and public.user_owns_farm(p.farm_id)
    )
  );
create policy "irrigation_plan_slots_delete_own" on public.irrigation_plan_slots
  for delete using (
    exists (
      select 1 from public.irrigation_plans p
      where p.id = plan_id and public.user_owns_farm(p.farm_id)
    )
  );

grant select, insert, update, delete on table public.irrigation_plans to authenticated;
grant select, insert, update, delete on table public.irrigation_plan_slots to authenticated;
