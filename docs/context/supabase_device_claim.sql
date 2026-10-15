-- SoilGood — Device claim by activation code (run in Supabase SQL Editor)
-- Lab pre-provisions kits; farmers type claim_code (e.g. SG-7K2M).
-- Safe to re-run. Does not change ingest_soil_reading.
--
-- LAB CHECKLIST (per physical kit)
-- 1. Flash ESP32 secrets.h: DEVICE_UID, INGEST_TOKEN, WiFi, Supabase anon URL/key
-- 2. Run the INSERT snippet below (same uid/token; unique claim_code)
-- 3. Write claim_code on tape/card on the box (farmer never sees ingest_token)
-- 4. Hand kit to farmer → app onboarding types the code

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
alter table public.devices
  alter column farm_id drop not null;

alter table public.devices
  add column if not exists claim_code text;

alter table public.devices
  add column if not exists claimed_at timestamptz;

-- Normalize existing codes if any were inserted lowercase.
update public.devices
set claim_code = upper(trim(claim_code))
where claim_code is not null
  and claim_code <> upper(trim(claim_code));

create unique index if not exists devices_claim_code_uidx
  on public.devices (claim_code)
  where claim_code is not null;

comment on column public.devices.claim_code is
  'Short activation code on the kit sticker (e.g. SG-7K2M). Not the ingest_token.';
comment on column public.devices.claimed_at is
  'When a farmer successfully claimed this device to their farm.';

-- ---------------------------------------------------------------------------
-- Farmers must not mint devices / ingest tokens from the app.
-- Lab provisions via SQL Editor (bypasses RLS). Claim is RPC-only.
-- ---------------------------------------------------------------------------
drop policy if exists "devices_insert_own" on public.devices;

-- ---------------------------------------------------------------------------
-- RPC: claim_device
-- ---------------------------------------------------------------------------
create or replace function public.claim_device(p_claim_code text)
returns table (
  id uuid,
  device_uid text,
  name text,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_farm_id uuid;
  v_code text;
  v_device public.devices%rowtype;
begin
  if v_uid is null then
    raise exception 'Not signed in'
      using errcode = 'P0001';
  end if;

  v_code := upper(trim(coalesce(p_claim_code, '')));
  if v_code = '' then
    raise exception 'Enter the claim code from your sensor box'
      using errcode = 'P0001';
  end if;

  select f.id
  into v_farm_id
  from public.farms f
  where f.owner_id = v_uid
  order by f.created_at asc
  limit 1;

  if v_farm_id is null then
    raise exception 'Create your farm location before linking a sensor'
      using errcode = 'P0001';
  end if;

  -- Several kits may share one farm. Which plot they watch is
  -- place_sensor_on_plot in supabase_plot_sensors.sql.

  select *
  into v_device
  from public.devices d
  where d.claim_code = v_code
  for update;

  if not found then
    raise exception 'Claim code not found. Check the code on your box'
      using errcode = 'P0001';
  end if;

  if v_device.farm_id is not null or v_device.status <> 'unclaimed' then
    raise exception 'This claim code was already used'
      using errcode = 'P0001';
  end if;

  update public.devices d
  set
    farm_id = v_farm_id,
    status = 'active',
    claimed_at = now()
  where d.id = v_device.id
  returning d.id, d.device_uid, d.name, d.status
  into id, device_uid, name, status;

  return next;
end;
$$;

revoke all on function public.claim_device(text) from public;
revoke all on function public.claim_device(text) from anon;
grant execute on function public.claim_device(text) to authenticated;

-- ---------------------------------------------------------------------------
-- LAB: provision one unclaimed kit (edit values, then run)
-- ---------------------------------------------------------------------------
-- insert into public.devices (
--   farm_id,
--   device_uid,
--   ingest_token,
--   claim_code,
--   name,
--   status
-- ) values (
--   null,
--   'SOILGOOD-ESP32-01',                          -- same as secrets.h DEVICE_UID
--   encode(gen_random_bytes(16), 'hex'),          -- paste same value into secrets.h INGEST_TOKEN
--   'SG-7K2M',                                    -- write on sticker (uppercase)
--   'SoilGood Sensor',
--   'unclaimed'
-- );
--
-- Tip: generate token first, copy it into secrets.h, then insert with that literal.
