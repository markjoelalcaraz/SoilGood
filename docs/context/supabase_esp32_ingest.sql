-- SoilGood — ESP32 ingest path (run in Supabase SQL Editor)
-- Lets the ESP32 POST readings with anon key + ingest_token.
-- Never put service_role on the ESP32.
--
-- Safe to re-run. DROP replaces old signatures (7-sensor, then 8-in-1 + salinity).

alter table public.devices
  add column if not exists ingest_token text;

alter table public.soil_readings
  add column if not exists salinity double precision;

update public.devices
set ingest_token = encode(gen_random_bytes(16), 'hex')
where ingest_token is null or length(trim(ingest_token)) = 0;

create unique index if not exists devices_ingest_token_idx
  on public.devices (ingest_token)
  where ingest_token is not null;

-- Pre-salinity signature (7 sensor doubles).
drop function if exists public.ingest_soil_reading(
  text, text,
  double precision, double precision, double precision, double precision,
  double precision, double precision, double precision,
  text, text
);

-- Current 8-in-1 signature (8 sensor doubles, including salinity).
drop function if exists public.ingest_soil_reading(
  text, text,
  double precision, double precision, double precision, double precision,
  double precision, double precision, double precision, double precision,
  text, text
);

create or replace function public.ingest_soil_reading(
  p_device_uid text,
  p_ingest_token text,
  p_moisture_percent double precision default null,
  p_ph double precision default null,
  p_soil_temperature_c double precision default null,
  p_ec double precision default null,
  p_salinity double precision default null,
  p_nitrogen double precision default null,
  p_phosphorus double precision default null,
  p_potassium double precision default null,
  p_validation_status text default 'ok',
  p_validation_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_reading_id uuid;
  v_status text;
begin
  if p_device_uid is null or length(trim(p_device_uid)) = 0 then
    raise exception 'device_uid required';
  end if;
  if p_ingest_token is null or length(trim(p_ingest_token)) < 8 then
    raise exception 'ingest_token required';
  end if;

  select d.id into v_device_id
  from public.devices d
  where d.device_uid = trim(p_device_uid)
    and d.ingest_token = trim(p_ingest_token);

  if v_device_id is null then
    raise exception 'invalid device credentials';
  end if;

  if p_moisture_percent is not null and (p_moisture_percent < 0 or p_moisture_percent > 100) then
    raise exception 'moisture out of range';
  end if;
  if p_ph is not null and (p_ph < 0 or p_ph > 14) then
    raise exception 'ph out of range';
  end if;
  -- Soil salinity in ppt; seawater is ~35 ppt. Probe max is usually far lower.
  if p_salinity is not null and (p_salinity < 0 or p_salinity > 50) then
    raise exception 'salinity out of range';
  end if;

  v_status := coalesce(nullif(trim(p_validation_status), ''), 'ok');
  if v_status not in ('ok', 'warning', 'error') then
    v_status := 'ok';
  end if;

  insert into public.soil_readings (
    device_id,
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
  ) values (
    v_device_id,
    p_moisture_percent,
    p_ph,
    p_soil_temperature_c,
    p_ec,
    p_salinity,
    p_nitrogen,
    p_phosphorus,
    p_potassium,
    v_status,
    p_validation_message
  )
  returning id into v_reading_id;

  update public.devices
  set last_seen_at = now(),
      status = 'active'
  where id = v_device_id;

  return v_reading_id;
end;
$$;

revoke all on function public.ingest_soil_reading(
  text, text,
  double precision, double precision, double precision, double precision,
  double precision, double precision, double precision, double precision,
  text, text
) from public;

grant execute on function public.ingest_soil_reading(
  text, text,
  double precision, double precision, double precision, double precision,
  double precision, double precision, double precision, double precision,
  text, text
) to anon, authenticated;
