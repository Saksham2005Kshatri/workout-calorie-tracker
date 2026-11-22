-- weight_log / daily_summary: RLS, upserts, uniqueness, constraints, read-only summaries, cascade.
begin;
select plan(36);

select tests.create_user('alice@example.test') as alice \gset
select tests.create_user('bob@example.test') as bob \gset

-- Fixtures (superuser).
insert into public.weight_log (user_id, weight_kg, logged_on) values
  (:'alice', 70.0, '2026-01-01'), (:'bob', 90.0, '2026-01-01');
insert into public.daily_summary
  (user_id, summary_date, calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count)
values
  (:'alice', '2026-01-01', 2000, 100, 200, 60, 300, 2100, 1),
  (:'bob',   '2026-01-01', 3000, 150, 300, 90, 500, 3000, 2);

-- ======================================================================== alice
select tests.authenticate_as(:'alice'::uuid);

select is((select count(*) from public.weight_log), 1::bigint, 'alice sees only her weights');
select is((select count(*) from public.daily_summary), 1::bigint, 'alice sees only her summaries');
select lives_ok($$insert into public.weight_log (weight_kg, logged_on) values (69.5, '2026-01-02')$$,
  'alice can log a weight (user_id defaults to her)');
select lives_ok(
  $$update public.weight_log set weight_kg = 69.8 where logged_on = '2026-01-02'$$,
  'alice can edit a weight the same day');
select lives_ok(
  format($$insert into public.weight_log (user_id, weight_kg, logged_on) values (%L, 69.0, '2026-01-02')
    on conflict (user_id, logged_on) do update set weight_kg = excluded.weight_kg$$, :'alice'),
  'a same-day upsert works (offline sync relies on it)');
select is((select weight_kg from public.weight_log where logged_on = '2026-01-02'), 69.00::numeric,
  'the upsert replaced the weight');
select lives_ok($$delete from public.weight_log where logged_on = '2026-01-02'$$, 'alice can delete a weight');
select throws_ok(
  $$insert into public.weight_log (weight_kg, logged_on) values (70.5, '2026-01-01')$$,
  '23505', null, 'a second weight for the same day is rejected');
select throws_ok(
  format($$insert into public.weight_log (user_id, weight_kg, logged_on) values (%L, 80, '2026-02-01')$$, :'bob'),
  '42501', null, 'alice cannot log a weight for bob');

-- daily_summary is read-only for clients.
select throws_ok(
  format($$insert into public.daily_summary
    (user_id, summary_date, calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count)
    values (%L, '2026-01-05', 1, 1, 1, 1, 1, 1, 1)$$, :'alice'),
  '42501', null, 'a client cannot insert a summary');
select throws_ok($$update public.daily_summary set calories_in = 1$$, '42501', null,
  'a client cannot update a summary');
select throws_ok($$delete from public.daily_summary$$, '42501', null, 'a client cannot delete a summary');

-- ======================================================================== bob
reset role;
select tests.authenticate_as(:'bob'::uuid);

select is((select count(*) from public.weight_log where user_id = :'alice'::uuid), 0::bigint,
  'bob cannot see alice''s weights');
select is((select count(*) from public.daily_summary where user_id = :'alice'::uuid), 0::bigint,
  'bob cannot see alice''s summaries');
select is_empty($$update public.weight_log set weight_kg = 1 where logged_on = '2026-01-01' and user_id <> auth.uid() returning 1$$,
  'bob cannot update alice''s weight');
select is_empty(
  format($$delete from public.weight_log where user_id = %L returning 1$$, :'alice'),
  'bob cannot delete alice''s weight');

reset role;
select is((select weight_kg from public.weight_log where user_id = :'alice'::uuid and logged_on = '2026-01-01'),
  70.00::numeric, 'alice''s weight is unchanged');

-- ======================================================================== signed out
select tests.authenticate_as_anon();
select throws_ok($$select * from public.weight_log$$, '42501', null, 'signed-out select on weight_log is denied');
select throws_ok($$select * from public.daily_summary$$, '42501', null, 'signed-out select on daily_summary is denied');
select throws_ok($$insert into public.weight_log (weight_kg) values (70)$$, '42501', null, 'signed-out insert is denied');
select throws_ok($$update public.weight_log set weight_kg = 1$$, '42501', null, 'signed-out update is denied');
select throws_ok($$delete from public.weight_log$$, '42501', null, 'signed-out delete is denied');

-- ======================================================================== constraints (superuser)
reset role;
select throws_ok(format($$insert into public.weight_log (user_id, weight_kg, logged_on) values (%L, 0, '2026-03-01')$$, :'alice'),
  '23514', null, 'a zero weight is rejected');
select throws_ok(format($$insert into public.weight_log (user_id, weight_kg, logged_on) values (%L, -5, '2026-03-02')$$, :'alice'),
  '23514', null, 'a negative weight is rejected');
select throws_ok(format($$insert into public.weight_log (user_id, weight_kg, logged_on) values (%L, 701, '2026-03-03')$$, :'alice'),
  '23514', null, 'an absurd weight is rejected');
select lives_ok(
  format($$insert into public.weight_log (user_id, weight_kg, logged_on)
    values (%L, 70.0, '2026-04-01'), (%L, 90.0, '2026-04-01')$$, :'alice', :'bob'),
  'two users may log the same day');
select throws_ok(
  format($$insert into public.daily_summary
    (user_id, summary_date, calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count)
    values (%L, '2026-01-09', -1, 1, 1, 1, 1, 1, 1)$$, :'alice'),
  '23514', null, 'a negative summary value is rejected');
select throws_ok(
  format($$insert into public.daily_summary
    (user_id, summary_date, calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count)
    values (%L, '2026-01-01', 1, 1, 1, 1, 1, 1, 1)$$, :'alice'),
  '23505', null, 'a second summary for the same day is rejected');
select throws_ok(
  format($$update public.weight_log set user_id = %L where user_id = %L$$, :'bob', :'alice'),
  '42501', 'user_id is immutable', 'a weight cannot change owner');

-- Server-side write (what the Phase 9 job does): allowed for the superuser, visible only to the owner.
select lives_ok(
  format($$insert into public.daily_summary
    (user_id, summary_date, calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count)
    values (%L, '2026-01-10', 1800, 90, 180, 50, 200, 2000, 0)$$, :'alice'),
  'the server job can write a summary');
select tests.authenticate_as(:'alice'::uuid);
select is((select count(*) from public.daily_summary where summary_date = '2026-01-10'), 1::bigint,
  'the owner sees the server-written summary');
reset role;
select tests.authenticate_as(:'bob'::uuid);
select is((select count(*) from public.daily_summary where summary_date = '2026-01-10'), 0::bigint,
  'another user does not');

-- ======================================================================== cascade
reset role;
select lives_ok(format($$delete from auth.users where id = %L$$, :'alice'), 'deleting an account succeeds');
select is((select count(*) from public.weight_log where user_id = :'alice'::uuid), 0::bigint, 'the account''s weights are gone');
select is((select count(*) from public.daily_summary where user_id = :'alice'::uuid), 0::bigint, 'the account''s summaries are gone');
select is((select count(*) from public.weight_log where user_id = :'bob'::uuid), 2::bigint, 'bob''s weights are untouched');

select * from finish();
rollback;
