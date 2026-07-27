-- SoilGood — grant table privileges to API roles
-- Needed because "Automatically expose new tables" was OFF at project create.
-- RLS still controls WHICH rows; GRANTs only allow the role to touch the table at all.
-- Paste into: Supabase → SQL Editor → Run

-- Authenticated users (logged-in app)
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

-- Anon (not logged in): no table data access — RLS + no grants keep it empty.
-- Auth signup/login still works via Auth API (does not need table grants).

-- Optional: allow anon to read nothing explicitly (default). Do NOT grant farms/readings to anon.
