-- SoilGood — several sensors on one farm, each placed on a crop plot.
-- Run after supabase_device_claim.sql. Safe to re-run.
--
-- A kit is still claimed with claim_device (sticker code → farm).
-- place_sensor_on_plot then sets which active planting that kit watches.
-- The app shows the sticker code: "Sensor (SG-7K2M) area is low".

alter table public.devices
  add column if not exists planting_id uuid references public.plantings (id) on delete set null;

create index if not exists devices_planting_id_idx
  on public.devices (planting_id)
  where planting_id is not null;

comment on column public.devices.planting_id is
  'Active crop plot this sensor watches. Null until the farmer places it.';

-- ---------------------------------------------------------------------------
-- RPC: place_sensor_on_plot
-- ---------------------------------------------------------------------------
create or replace function public.place_sensor_on_plot(
  p_device_id uuid,
  p_planting_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_farm_id uuid;
  v_plot_farm uuid;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Not signed in'
      using errcode = 'P0001';
  end if;

  if p_device_id is null or p_planting_id is null then
    raise exception 'Choose a sensor and a plot'
      using errcode = 'P0001';
  end if;

  select d.farm_id
  into v_farm_id
  from public.devices d
  where d.id = p_device_id;

  if v_farm_id is null or not public.user_owns_farm(v_farm_id) then
    raise exception 'Sensor not on your farm'
      using errcode = 'P0001';
  end if;

  select p.farm_id, p.status
  into v_plot_farm, v_status
  from public.plantings p
  where p.id = p_planting_id;

  if v_plot_farm is null or v_plot_farm <> v_farm_id then
    raise exception 'That plot is not on your farm'
      using errcode = 'P0001';
  end if;

  if v_status <> 'active' then
    raise exception 'Choose the current crop for this sensor'
      using errcode = 'P0001';
  end if;

  update public.devices d
  set planting_id = p_planting_id
  where d.id = p_device_id;
end;
$$;

revoke all on function public.place_sensor_on_plot(uuid, uuid) from public;
revoke all on function public.place_sensor_on_plot(uuid, uuid) from anon;
grant execute on function public.place_sensor_on_plot(uuid, uuid) to authenticated;

-- Lift the old "one sensor per farm" guard. Same signature the app already calls.
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
