-- SoilGood — one active planting per farm (v1) + `replaced` status
-- Run in Supabase SQL Editor on live / existing projects.
-- Safe to re-run.
--
-- 1) Allow status = replaced (Change crop ends a planting this way).
-- 2) Ends duplicate active rows (keeps newest per farm) as replaced.
-- 3) Enforces uniqueness so double-tap / race cannot insert a second active.

-- ---------------------------------------------------------------------------
-- Status check: add `replaced` (keep harvested / failed for later use)
-- ---------------------------------------------------------------------------
alter table public.plantings drop constraint if exists plantings_status_check;
alter table public.plantings
  add constraint plantings_status_check
  check (status in ('planned', 'active', 'harvested', 'failed', 'replaced'));

-- ---------------------------------------------------------------------------
-- Cleanup: keep newest active planting per farm; mark older ones replaced
-- ---------------------------------------------------------------------------
with ranked as (
  select
    id,
    row_number() over (
      partition by farm_id
      order by created_at desc nulls last, id desc
    ) as rn
  from public.plantings
  where status = 'active'
)
update public.plantings p
set status = 'replaced'
from ranked r
where p.id = r.id
  and r.rn > 1;

-- ---------------------------------------------------------------------------
-- Enforce: at most one active planting per farm
-- ---------------------------------------------------------------------------
create unique index if not exists plantings_one_active_per_farm_uidx
  on public.plantings (farm_id)
  where status = 'active';
