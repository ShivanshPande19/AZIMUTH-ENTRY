-- =============================================================================
-- Visitor photos
-- =============================================================================
-- Adds an OPTIONAL photo to each visitor entry:
--   * a `photo_path` column on public.visitors (the Storage object key),
--   * an extended add_visitor() RPC that accepts the photo path,
--   * a PUBLIC Storage bucket `visitor-photos` that any logged-in user can
--     upload to and anyone can read (photos are small, pre-compressed JPEGs
--     with unguessable random filenames).
--
-- Photos are intentionally NOT as locked-down as phone numbers — the guard who
-- takes the photo and the owner both need to see it in the register. If you
-- prefer private photos + signed URLs, make the bucket private and adjust the
-- read policy / app accordingly.
-- =============================================================================

-- 1. Column on the guard-facing table.
alter table public.visitors
  add column if not exists photo_path text;

-- 2. Extend add_visitor() with an optional photo path.
--    Drop the old 4-argument signature so PostgREST resolves a single function.
drop function if exists public.add_visitor(text, text, text, text);

create or replace function public.add_visitor(
  p_name       text,
  p_phone      text,
  p_company    text default null,
  p_purpose    text default null,
  p_photo_path text default null
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

  insert into public.visitors
    (name, company, purpose, phone_masked, photo_path, created_by)
  values
    (trim(p_name),
     nullif(trim(p_company), ''),
     nullif(trim(p_purpose), ''),
     public.mask_phone(p_phone),
     nullif(trim(p_photo_path), ''),
     auth.uid())
  returning id into v_id;

  if coalesce(trim(p_phone), '') <> '' then
    insert into public.visitor_contacts (visitor_id, phone)
    values (v_id, trim(p_phone));
  end if;

  return v_id;
end;
$$;

revoke all on function public.add_visitor(text, text, text, text, text)
  from public, anon;
grant execute on function public.add_visitor(text, text, text, text, text)
  to authenticated;

-- 3. Public Storage bucket for the photos.
insert into storage.buckets (id, name, public)
values ('visitor-photos', 'visitor-photos', true)
on conflict (id) do update set public = true;

-- Any logged-in user (guard or owner) may upload a visitor photo.
drop policy if exists "auth upload visitor photos" on storage.objects;
create policy "auth upload visitor photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'visitor-photos');

-- Public read (the app renders photos via the public URL). Harmless even for a
-- public bucket; makes intent explicit.
drop policy if exists "public read visitor photos" on storage.objects;
create policy "public read visitor photos"
  on storage.objects for select to public
  using (bucket_id = 'visitor-photos');
