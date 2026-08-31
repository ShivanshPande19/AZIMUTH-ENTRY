-- =============================================================================
-- Create the first accounts and assign roles.
-- =============================================================================
-- Step 1 — Create the login users in the Supabase Dashboard:
--   Authentication > Users > "Add user" > enter email + password
--   Do this once for the OWNER (you) and once for each GUARD.
--   (Every new user automatically gets a 'guard' profile via a trigger.)
--
-- Step 2 — Promote your own account to OWNER by running the query below in the
--   Supabase SQL editor. Replace the email with the one you used for yourself.
-- -----------------------------------------------------------------------------

update public.profiles
set role = 'owner', full_name = 'Factory Owner'
where id = (select id from auth.users where email = 'owner@example.com');

-- Optionally set friendly names for guards:
-- update public.profiles set full_name = 'Gate Guard 1'
-- where id = (select id from auth.users where email = 'guard1@example.com');

-- -----------------------------------------------------------------------------
-- Verify who is who:
-- -----------------------------------------------------------------------------
-- select u.email, p.role, p.full_name
-- from public.profiles p join auth.users u on u.id = p.id
-- order by p.role;
