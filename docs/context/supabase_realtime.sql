-- Live updates for the farmer app.
-- Run once in the Supabase SQL Editor. Already-added tables are skipped.
--
-- devices omits ingest_token and device_uid so Realtime does not push
-- the ESP32 secret to the phone. If devices was added earlier with every
-- column, leave that row; do not re-add it here.

do $$
begin
  alter publication supabase_realtime add table public.soil_readings;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.farm_notifications;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.plantings;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.farms;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.ai_assessments;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.ai_recommendations;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.irrigation_plans;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.irrigation_plan_slots;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.farm_actions;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.crops;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.devices (
    id,
    farm_id,
    claim_code,
    name,
    status,
    last_seen_at,
    claimed_at,
    created_at,
    planting_id
  );
exception when duplicate_object then null;
end $$;
