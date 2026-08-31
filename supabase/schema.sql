-- =============================================================================
-- Gate Entry — Visitor/Client Management  |  Supabase schema + security model
-- =============================================================================
-- SECURITY GOAL:
--   A guard (at the gate tablet) can register visitors and record entry/exit
--   times, and the visitor types their own phone number on the tablet. BUT the
--   guard must NEVER be able to read a full phone number back — not on screen,
--   not via the API, not by inspecting the app. Only an OWNER can reveal a full
--   number, and every reveal is written to an audit log.
--
-- HOW IT IS ENFORCED (defense in depth):
--   1. Phone numbers live in a SEPARATE table (visitor_contacts) that has NO
--      row-level-security policy granting SELECT to anyone. With RLS enabled and
--      no SELECT policy, PostgREST returns nothing — the column is unreachable
--      from any client, guard or owner.
--   2. All sensitive operations go through SECURITY DEFINER functions (RPCs)
--      that run with elevated rights and enforce role checks in one place:
--        - add_visitor()   : anyone logged in can insert (guard or owner)
--        - mark_exit()     : anyone logged in can set exit time
--        - reveal_phone()  : OWNER ONLY, and it writes an audit row every time
--   3. The guard-facing table (visitors) only stores a MASKED phone string
--      (e.g. '98••••••10') so the guard has a reference without the real number.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PROFILES  (one row per auth user, holds the role)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text        not null default '',
  role       text        not null default 'guard'
             check (role in ('guard', 'owner')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any logged-in user can read their OWN profile (needed to know their role).
drop policy if exists "read own profile" on public.profiles;
create policy "read own profile"
  on public.profiles for select
  using (auth.uid() = id);

-- Owners can read every profile (for the "manage staff" view).
drop policy if exists "owner reads all profiles" on public.profiles;
create policy "owner reads all profiles"
  on public.profiles for select
  using (public.is_owner());

-- Auto-create a profile row when a new auth user signs up (default role: guard).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id,
          coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          coalesce(new.raw_user_meta_data ->> 'role', 'guard'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: is the current user an owner?  (SECURITY DEFINER so it can read
-- profiles regardless of the caller's own RLS.)
create or replace function public.is_owner()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'owner'
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. VISITORS  (guard-facing record — NO real phone number here)
-- ---------------------------------------------------------------------------
create table if not exists public.visitors (
  id           uuid primary key default gen_random_uuid(),
  name         text        not null,
  company      text,
  purpose      text,
  phone_masked text        not null default '',   -- e.g. '98••••••10'
  entry_time   timestamptz not null default now(),
  exit_time    timestamptz,
  created_by   uuid        references auth.users (id),
  created_at   timestamptz not null default now()
);

create index if not exists visitors_entry_time_idx on public.visitors (entry_time desc);

alter table public.visitors enable row level security;

-- Every logged-in user (guard + owner) may READ the visitor list.
-- Note: this table intentionally contains NO real phone number.
drop policy if exists "read visitors" on public.visitors;
create policy "read visitors"
  on public.visitors for select
  using (auth.role() = 'authenticated');

-- Direct INSERT/UPDATE are NOT granted here on purpose. All writes happen
-- through the RPCs below so masking and audit rules cannot be bypassed.

-- ---------------------------------------------------------------------------
-- 3. VISITOR_CONTACTS  (the real phone number — locked down completely)
-- ---------------------------------------------------------------------------
create table if not exists public.visitor_contacts (
  visitor_id uuid primary key references public.visitors (id) on delete cascade,
  phone      text not null
);

alter table public.visitor_contacts enable row level security;
-- INTENTIONALLY NO POLICIES. With RLS on and zero policies, no client role can
-- select/insert/update/delete directly. The only way in is via the SECURITY
-- DEFINER functions below. This is what makes the phone number un-leakable.

-- ---------------------------------------------------------------------------
-- 4. PHONE_VIEW_AUDIT  (who revealed which number, and when)
-- ---------------------------------------------------------------------------
create table if not exists public.phone_view_audit (
  id         uuid primary key default gen_random_uuid(),
  visitor_id uuid not null references public.visitors (id) on delete cascade,
  viewed_by  uuid not null references auth.users (id),
  viewed_at  timestamptz not null default now()
);

create index if not exists audit_viewed_at_idx on public.phone_view_audit (viewed_at desc);

alter table public.phone_view_audit enable row level security;

-- Only owners can read the audit log.
drop policy if exists "owner reads audit" on public.phone_view_audit;
create policy "owner reads audit"
  on public.phone_view_audit for select
  using (public.is_owner());

-- ---------------------------------------------------------------------------
-- 5. RPCs  (the only supported way to touch sensitive data)
-- ---------------------------------------------------------------------------

-- Build a masked phone string: keep first 2 and last 2 digits, dot out the rest.
-- '9876543210'  ->  '98••••••10'
create or replace function public.mask_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  digits text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  n      int  := length(digits);
begin
  if n = 0 then
    return '';
  elsif n <= 4 then
    return repeat('•', n);
  else
    return left(digits, 2) || repeat('•', n - 4) || right(digits, 2);
  end if;
end;
$$;

-- Register a new visitor. Callable by any logged-in user (guard or owner).
-- Stores the real number in the locked table and only a masked copy in visitors.
create or replace function public.add_visitor(
  p_name    text,
  p_phone   text,
  p_company text default null,
  p_purpose text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'name is required';
  end if;

  insert into public.visitors (name, company, purpose, phone_masked, created_by)
  values (trim(p_name), nullif(trim(p_company), ''), nullif(trim(p_purpose), ''),
          public.mask_phone(p_phone), auth.uid())
  returning id into v_id;

  if coalesce(trim(p_phone), '') <> '' then
    insert into public.visitor_contacts (visitor_id, phone)
    values (v_id, trim(p_phone));
  end if;

  return v_id;
end;
$$;

-- Record the exit time for a visitor. Any logged-in user.
create or replace function public.mark_exit(p_visitor_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  update public.visitors
    set exit_time = now()
    where id = p_visitor_id and exit_time is null;
end;
$$;

-- Reveal a full phone number. OWNER ONLY. Writes an audit row every call.
create or replace function public.reveal_phone(p_visitor_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v_phone text;
begin
  if not public.is_owner() then
    raise exception 'only the owner can view phone numbers';
  end if;

  select phone into v_phone
    from public.visitor_contacts
    where visitor_id = p_visitor_id;

  insert into public.phone_view_audit (visitor_id, viewed_by)
  values (p_visitor_id, auth.uid());

  return coalesce(v_phone, '');
end;
$$;

-- Lock down function execution to logged-in users only.
revoke all on function public.add_visitor(text, text, text, text)   from public, anon;
revoke all on function public.mark_exit(uuid)                        from public, anon;
revoke all on function public.reveal_phone(uuid)                     from public, anon;
grant  execute on function public.add_visitor(text, text, text, text) to authenticated;
grant  execute on function public.mark_exit(uuid)                     to authenticated;
grant  execute on function public.reveal_phone(uuid)                  to authenticated;
grant  execute on function public.is_owner()                          to authenticated;

-- =============================================================================
-- DONE. See README for how to create the first owner and guard accounts.
-- =============================================================================
