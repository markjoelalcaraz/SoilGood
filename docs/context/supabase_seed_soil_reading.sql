-- SoilGood — seed one mock soil reading (no ESP32 required)
-- Paste into Supabase SQL Editor and Run.
-- Safe to re-run: each run inserts a new "latest" snapshot.
--
-- Needs: a claimed device from onboarding (devices row).
-- Seeds all 8-in-1 fields: moisture, pH, temperature, EC, salinity, N, P, K.
-- Values sit inside Rice / Corn / Tomato catalog ranges so Crops can match.

do $$
declare
  v_device_count int;
  v_crop_count int;
  v_inserted int := 0;
begin
  select count(*) into v_device_count from public.devices;
  if v_device_count = 0 then
    raise exception
      'No devices found. Finish onboarding (claim a device_uid) first, then run this seed again.';
  end if;

  select count(*) into v_crop_count from public.crops;
  if v_crop_count = 0 then
    raise exception
      'Crop catalog is empty. Run supabase_schema.sql (and supabase_crops_home_ai.sql), then this seed.';
  end if;

  -- One snapshot per claimed device. Crops uses the latest row for that farm.
  insert into public.soil_readings (
    device_id,
    recorded_at,
    moisture_percent,
    ph,
    soil_temperature_c,
    ec,
    salinity,
    nitrogen,
    phosphorus,
    potassium,
    validation_status,
    validation_message
  )
  select
    d.id,
    now(),
    65,    -- 1 moisture %     (Rice 60–90, Corn 50–80, Tomato 60–80)
    6.4,   -- 2 pH             (Rice 5.5–7.0, Corn 5.8–7.0, Tomato 6.0–6.8)
    27,    -- 3 temperature °C (Rice 20–35, Corn 18–32, Tomato 18–30)
    0.8,   -- 4 EC dS/m
    0.4,   -- 5 salinity ppt
    70,    -- 6 nitrogen mg/kg
    32,    -- 7 phosphorus mg/kg
    130,   -- 8 potassium mg/kg
    'ok',
    'Mock seed for UI / crop matching (no ESP32).'
  from public.devices d;

  get diagnostics v_inserted = row_count;

  update public.devices
  set last_seen_at = now(),
      status = 'active';

  raise notice 'Inserted % soil reading(s) for % device(s). Pull to refresh Crops.',
    v_inserted, v_device_count;
end;
$$;

-- Confirm the latest 8-in-1 row:
select
  sr.id,
  d.device_uid,
  sr.recorded_at,
  sr.moisture_percent,
  sr.ph,
  sr.soil_temperature_c,
  sr.ec,
  sr.salinity,
  sr.nitrogen,
  sr.phosphorus,
  sr.potassium,
  sr.validation_status
from public.soil_readings sr
join public.devices d on d.id = sr.device_id
order by sr.recorded_at desc
limit 5;
