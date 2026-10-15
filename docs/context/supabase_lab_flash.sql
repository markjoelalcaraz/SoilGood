-- SoilGood — Lab flash tracking (run after supabase_admin.sql)
-- Marks when a kit was burned via Lab Flasher. Safe to re-run.

alter table public.devices
  add column if not exists flashed_at timestamptz;

alter table public.devices
  add column if not exists flash_status text;

alter table public.devices
  drop constraint if exists devices_flash_status_check;

alter table public.devices
  add constraint devices_flash_status_check
  check (
    flash_status is null
    or flash_status in ('pending', 'flashed', 'error')
  );

comment on column public.devices.flashed_at is
  'When Lab Flasher successfully wrote credentials to the ESP32.';
comment on column public.devices.flash_status is
  'pending | flashed | error — set by admin_mark_device_flashed / flasher.';

create or replace function public.admin_mark_device_flashed(p_id uuid)
returns table (
  id uuid,
  claim_code text,
  flash_status text,
  flashed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0001';
  end if;
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = 'P0001';
  end if;

  return query
  update public.devices d
  set
    flash_status = 'flashed',
    flashed_at = now()
  where d.id = p_id
  returning d.id, d.claim_code, d.flash_status, d.flashed_at;
end;
$$;

revoke all on function public.admin_mark_device_flashed(uuid) from public;
revoke all on function public.admin_mark_device_flashed(uuid) from anon;
grant execute on function public.admin_mark_device_flashed(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Refresh list/get RPCs so Admin Web can show flashed_at (null = Not flashed)
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_devices()
returns table (
  id uuid,
  device_uid text,
  claim_code text,
  name text,
  status text,
  farm_id uuid,
  farm_name text,
  owner_email text,
  last_seen_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz,
  flashed_at timestamptz,
  flash_status text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0001';
  end if;
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = 'P0001';
  end if;

  return query
  select
    d.id,
    d.device_uid,
    d.claim_code,
    d.name,
    d.status,
    d.farm_id,
    f.name as farm_name,
    u.email::text as owner_email,
    d.last_seen_at,
    d.claimed_at,
    d.created_at,
    d.flashed_at,
    d.flash_status
  from public.devices d
  left join public.farms f on f.id = d.farm_id
  left join auth.users u on u.id = f.owner_id
  order by d.created_at desc;
end;
$$;

revoke all on function public.admin_list_devices() from public;
revoke all on function public.admin_list_devices() from anon;
grant execute on function public.admin_list_devices() to authenticated;

create or replace function public.admin_get_device(p_id uuid)
returns table (
  id uuid,
  device_uid text,
  ingest_token text,
  claim_code text,
  name text,
  status text,
  farm_id uuid,
  farm_name text,
  owner_email text,
  last_seen_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz,
  flashed_at timestamptz,
  flash_status text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0001';
  end if;
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = 'P0001';
  end if;

  return query
  select
    d.id,
    d.device_uid,
    d.ingest_token,
    d.claim_code,
    d.name,
    d.status,
    d.farm_id,
    f.name as farm_name,
    u.email::text as owner_email,
    d.last_seen_at,
    d.claimed_at,
    d.created_at,
    d.flashed_at,
    d.flash_status
  from public.devices d
  left join public.farms f on f.id = d.farm_id
  left join auth.users u on u.id = f.owner_id
  where d.id = p_id;
end;
$$;

revoke all on function public.admin_get_device(uuid) from public;
revoke all on function public.admin_get_device(uuid) from anon;
grant execute on function public.admin_get_device(uuid) to authenticated;
