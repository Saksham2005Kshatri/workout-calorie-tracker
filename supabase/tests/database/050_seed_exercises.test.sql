-- Exercise library seed: size, coverage, uniqueness, idempotency, and read-only for clients.
begin;
select plan(11);

select tests.create_user('alice@example.test') as alice \gset

select cmp_ok((select count(*) from public.exercise where created_by is null), '>=', 100::bigint,
  'at least 100 exercises are seeded');
select is(
  (select count(*) from (
    select muscle_group from public.exercise where created_by is null
    group by muscle_group having count(*) >= 5) g),
  10::bigint, 'every muscle group has at least five seeded exercises');
select is((select count(*) from public.exercise where created_by is null and equipment is null), 0::bigint,
  'every seeded exercise has equipment');
select is((select count(*) from public.exercise where created_by is null and is_custom), 0::bigint,
  'no seeded exercise is flagged custom');
select is(
  (select count(distinct lower(name)) from public.exercise where created_by is null),
  (select count(*) from public.exercise where created_by is null),
  'seeded names are unique, ignoring case');

-- Idempotency: re-applying the same rows changes nothing and creates no duplicates.
select count(*) as seeded_n from public.exercise where created_by is null \gset
insert into public.exercise (name, muscle_group, equipment, created_by)
select name, muscle_group, equipment, null from public.exercise where created_by is null
on conflict (lower(name)) where created_by is null
do update set muscle_group = excluded.muscle_group, equipment = excluded.equipment;
select is((select count(*) from public.exercise where created_by is null), :seeded_n::bigint,
  're-applying the seed adds no rows');

-- Corrections can ship as a later migration through the same upsert.
insert into public.exercise (name, muscle_group, equipment, created_by)
values ('Plank', 'full_body', 'bodyweight', null)
on conflict (lower(name)) where created_by is null
do update set muscle_group = excluded.muscle_group, equipment = excluded.equipment;
select is((select muscle_group from public.exercise where lower(name) = 'plank' and created_by is null),
  'full_body', 'a correction updates the existing row');
select is((select count(*) from public.exercise where lower(name) = 'plank'), 1::bigint,
  'and does not duplicate it');

-- Clients can read the library but not change it.
select tests.authenticate_as(:'alice'::uuid);
select is((select count(*) from public.exercise), :seeded_n::bigint,
  'a signed-in user sees the whole library');
select is_empty($$update public.exercise set muscle_group = 'cardio' returning 1$$,
  'a client cannot update seeded exercises');
select is_empty($$delete from public.exercise returning 1$$, 'a client cannot delete seeded exercises');

select * from finish();
rollback;
