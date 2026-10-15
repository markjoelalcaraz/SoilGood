-- SoilGood — Admin role + device provision RPCs (run in Supabase SQL Editor)
-- Safe to re-run. Requires devices claim columns from supabase_device_claim.sql.
-- Does NOT promote any user to admin automatically (see commented snippet at end).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- profiles.role
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists role text not null default 'farmer';

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('farmer', 'admin'));

comment on column public.profiles.role is
  'farmer = mobile app; admin = Flutter web ops console.';

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- admin_provision_device
-- ---------------------------------------------------------------------------
create or replace function public.admin_provision_device(
  p_name text default 'SoilGood Sensor'
)
returns table (
  id uuid,
  device_uid text,
  ingest_token text,
  claim_code text,
  name text,
  status text,
  farm_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid text;
  v_token text;
  v_code text;
  v_name text := nullif(trim(coalesce(p_name, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = 'P0001';
  end if;
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = 'P0001';
  end if;

  if v_name is null then
    v_name := 'SoilGood Sensor';
  end if;

  -- Unique device_uid / claim_code (retry a few times on collision).
  for i in 1..8 loop
    v_uid := 'SOILGOOD-' || upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 10));
    v_token := encode(gen_random_bytes(16), 'hex');
    v_code := 'SG-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 4));

    begin
      return query
      insert into public.devices (
        farm_id,
        device_uid,
        ingest_token,
        claim_code,
        name,
        status
      ) values (
        null,
        v_uid,
        v_token,
        v_code,
        v_name,
        'unclaimed'
      )
      returning
        devices.id,
        devices.device_uid,
        devices.ingest_token,
        devices.claim_code,
        devices.name,
        devices.status,
        devices.farm_id,
        devices.created_at;
      return;
    exception
      when unique_violation then
        null; -- retry
    end;
  end loop;

  raise exception 'Could not allocate unique device ids; try again'
    using errcode = 'P0001';
end;
$$;

revoke all on function public.admin_provision_device(text) from public;
revoke all on function public.admin_provision_device(text) from anon;
grant execute on function public.admin_provision_device(text) to authenticated;

-- ---------------------------------------------------------------------------
-- admin_list_devices
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
  created_at timestamptz
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
    d.created_at
  from public.devices d
  left join public.farms f on f.id = d.farm_id
  left join auth.users u on u.id = f.owner_id
  order by d.created_at desc;
end;
$$;

revoke all on function public.admin_list_devices() from public;
revoke all on function public.admin_list_devices() from anon;
grant execute on function public.admin_list_devices() to authenticated;

-- ---------------------------------------------------------------------------
-- admin_get_device (includes ingest_token for flash)
-- ---------------------------------------------------------------------------
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
  created_at timestamptz
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
    d.created_at
  from public.devices d
  left join public.farms f on f.id = d.farm_id
  left join auth.users u on u.id = f.owner_id
  where d.id = p_id;
end;
$$;

revoke all on function public.admin_get_device(uuid) from public;
revoke all on function public.admin_get_device(uuid) from anon;
grant execute on function public.admin_get_device(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Promote admin — run ONLY after that Gmail has signed up once
-- ---------------------------------------------------------------------------
-- update public.profiles p
-- set role = 'admin'
-- from auth.users u
-- where p.id = u.id
--   and lower(u.email) = 'markjoeldelrosarioalcaraz@gmail.com';
