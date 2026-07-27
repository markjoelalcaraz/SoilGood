-- Enable Realtime for live Home dashboard updates
-- Run once in Supabase SQL Editor if soil_readings is not yet in the publication.

alter publication supabase_realtime add table public.soil_readings;
