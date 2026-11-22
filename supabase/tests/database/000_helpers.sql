-- Test helpers. Committed (not rolled back) so every later test file can use them.
-- Lives in the `tests` schema, which no client role can use, and is excluded from
-- the public-schema guards in 900_guards.test.sql.
--
-- Usage inside a test file (all within begin/rollback):
--   select tests.create_user('alice@example.test') as alice \gset
--   select tests.authenticate_as(:'alice'::uuid);   -- now acting as alice
--   reset role;                                     -- back to superuser
--
-- The helpers are only callable as the superuser, so ALWAYS run `reset role;` before
-- calling one after impersonating someone.

create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
revoke all on schema tests from public, anon, authenticated;

-- Minimal auth.users column set. Revisit when the CLI / GoTrue version is bumped.
-- Also creates the public.users row when that table exists, ignoring conflicts so a
-- future sign-up trigger (Phase 3) cannot break every test.
create or replace function tests.create_user(p_email text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    p_email, '', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now()
  );

  if to_regclass('public.users') is not null then
    execute format(
      'insert into public.users (id, display_name, timezone) values (%L, %L, %L) on conflict do nothing',
      v_id, split_part(p_email, '@', 1), 'UTC'
    );
  end if;

  return v_id;
end;
$$;

-- Impersonate a signed-in user: switch to the `authenticated` role and set the JWT claims
-- that auth.uid() reads.
create or replace function tests.authenticate_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  set local role authenticated;
end;
$$;

-- Impersonate a signed-out caller: `anon` role, no claims.
create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  set local role anon;
end;
$$;

begin;
select plan(3);
select has_function('tests', 'create_user', array['text'], 'create_user helper exists');
select has_function('tests', 'authenticate_as', array['uuid'], 'authenticate_as helper exists');
select has_function('tests', 'authenticate_as_anon', 'authenticate_as_anon helper exists');
select * from finish();
rollback;
