-- Schema-wide guards. These protect against future mistakes, not just today's tables:
-- a new table that forgets RLS, a stray grant to anon, a definer function without a
-- pinned search_path, and so on all fail here with the offending name in the output.
-- Scope: the `public` schema (the `tests` and `private` schemas are checked for isolation).
begin;
select plan(13);

-- ---- RLS everywhere
select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity$$,
  'every public table has RLS enabled');
select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)$$,
  'every public table has at least one policy');

-- ---- Grants: anon and PUBLIC hold nothing; authenticated holds exactly the allowed set.
select is_empty(
  $$select c.relname, a.privilege_type
    from pg_class c join pg_namespace n on n.oid = c.relnamespace,
         lateral aclexplode(c.relacl) a
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and (a.grantee = 0 or a.grantee = (select oid from pg_roles where rolname = 'anon'))$$,
  'anon and PUBLIC hold no privilege on any public table or view');
select results_eq(
  $$select (c.relname::text collate "default"), string_agg(a.privilege_type, ',' order by a.privilege_type)::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace,
         lateral aclexplode(c.relacl) a
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and a.grantee = (select oid from pg_roles where rolname = 'authenticated')
    group by c.relname order by c.relname$$,
  $$values
    ('daily_summary'::text, 'SELECT'::text),
    ('exercise', 'DELETE,INSERT,SELECT,UPDATE'),
    ('exercise_set', 'DELETE,INSERT,SELECT,UPDATE'),
    ('food_item', 'DELETE,INSERT,SELECT,UPDATE'),
    ('meal', 'DELETE,INSERT,SELECT,UPDATE'),
    ('meal_item', 'DELETE,INSERT,SELECT,UPDATE'),
    ('meal_totals', 'SELECT'),
    ('session_exercise', 'DELETE,INSERT,SELECT,UPDATE'),
    ('user_profile', 'INSERT,SELECT,UPDATE'),
    ('users', 'SELECT,UPDATE'),
    ('weight_log', 'DELETE,INSERT,SELECT,UPDATE'),
    ('workout_session', 'DELETE,INSERT,SELECT,UPDATE')$$,
  'authenticated holds exactly the expected privileges (a new object must be added here on purpose)');

-- ---- Views obey the caller's RLS
select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v'
      and not coalesce(c.reloptions @> array['security_invoker=true'], false)$$,
  'every public view is security_invoker');

-- ---- Functions and internal schemas
select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))$$,
  'no public-schema function is callable by client roles');
select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private', 'tests') and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')$$,
  'every SECURITY DEFINER function pins its search_path');
select ok(
  not has_schema_privilege('anon', 'private', 'usage') and not has_schema_privilege('authenticated', 'private', 'usage'),
  'client roles cannot use the private schema');
select ok(
  not has_schema_privilege('anon', 'tests', 'usage') and not has_schema_privilege('authenticated', 'tests', 'usage'),
  'client roles cannot use the tests schema');

-- ---- Ownership columns are indexed (RLS policies filter on them)
select is_empty(
  $$select c.relname, a.attname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attname in ('user_id', 'created_by') and not a.attisdropped
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (select 1 from pg_index i where i.indrelid = c.oid and i.indkey[0] = a.attnum)$$,
  'every user_id / created_by column leads an index');

-- ---- Owners cannot change (every client-writable table has the guard trigger)
select is_empty(
  $$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and c.relname <> 'daily_summary'
      and not exists (
        select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
        join pg_namespace pn on pn.oid = p.pronamespace
        where t.tgrelid = c.oid and not t.tgisinternal
          and pn.nspname = 'private' and p.proname = 'forbid_owner_change')$$,
  'every client-writable table forbids owner changes');

-- ---- Account deletion reaches everything
select is_empty(
  $$select conrelid::regclass::text, conname from pg_constraint
    where contype = 'f' and confrelid = 'public.users'::regclass and confdeltype <> 'c'$$,
  'every foreign key to users cascades on delete');
select is_empty(
  $$select conname from pg_constraint
    where contype = 'f' and conrelid = 'public.users'::regclass
      and confrelid = 'auth.users'::regclass and confdeltype <> 'c'$$,
  'users cascades from the auth user');

select * from finish();
rollback;
