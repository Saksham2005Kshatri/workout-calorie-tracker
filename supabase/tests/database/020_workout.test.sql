-- exercise / workout_session / session_exercise / exercise_set:
-- RLS, ownership chain, reference visibility, constraints, immutability, cascades.
begin;
select plan(61);

select tests.create_user('alice@example.test') as alice \gset
select tests.create_user('bob@example.test') as bob \gset

-- Fixtures (superuser).
insert into public.exercise (id, name, muscle_group, equipment, created_by) values
  ('00000000-0000-0000-0000-0000000000e1', 'Test Bench Press', 'chest', 'barbell', null),
  ('00000000-0000-0000-0000-0000000000e2', 'Alice Move', 'core', 'bodyweight', :'alice'),
  ('00000000-0000-0000-0000-0000000000e3', 'Bob Move', 'back', 'cable', :'bob');

insert into public.workout_session (id, user_id, notes) values
  ('00000000-0000-0000-0000-0000000000a1', :'alice', 'alice session'),
  ('00000000-0000-0000-0000-0000000000b1', :'bob', 'bob session');
insert into public.session_exercise (id, session_id, user_id, exercise_id, position) values
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a1', :'alice',
   '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000a1', :'alice',
   '00000000-0000-0000-0000-0000000000e2', 2),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b1', :'bob',
   '00000000-0000-0000-0000-0000000000e1', 1);
insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps) values
  ('00000000-0000-0000-0000-0000000000a2', 1, :'alice', 60, 8),
  ('00000000-0000-0000-0000-0000000000b2', 1, :'bob', 80, 5);

-- ======================================================================== alice
select tests.authenticate_as(:'alice'::uuid);

select is((select count(*) from public.workout_session), 1::bigint, 'alice sees only her session');
select is((select count(*) from public.session_exercise), 2::bigint, 'alice sees only her session exercises');
select is((select count(*) from public.exercise_set), 1::bigint, 'alice sees only her sets');
select lives_ok($$insert into public.workout_session (notes) values ('second')$$,
  'alice can create a session (user_id defaults to her)');
select lives_ok(
  $$insert into public.session_exercise (session_id, exercise_id, position)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', 3)$$,
  'alice can add an exercise to her session');
select lives_ok(
  $$insert into public.exercise_set (session_exercise_id, set_no, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 2, 62.5, 8)$$,
  'alice can add a set');
select lives_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 2, %L, 65, 6)
    on conflict (session_exercise_id, set_no) do update set weight_kg = excluded.weight_kg, reps = excluded.reps$$,
    :'alice'),
  'an upsert that leaves the owner unchanged works (offline sync relies on it)');
select is((select weight_kg from public.exercise_set where set_no = 2), 65.00::numeric,
  'the upsert updated the set');
select lives_ok(
  $$delete from public.exercise_set where session_exercise_id = '00000000-0000-0000-0000-0000000000a2' and set_no = 2$$,
  'alice can delete her set');

-- Reference data.
select is((select count(*) from public.exercise where id = '00000000-0000-0000-0000-0000000000e1'), 1::bigint,
  'alice sees the seeded exercise');
select is((select count(*) from public.exercise where id = '00000000-0000-0000-0000-0000000000e2'), 1::bigint,
  'alice sees her own custom exercise');
select is((select count(*) from public.exercise where id = '00000000-0000-0000-0000-0000000000e3'), 0::bigint,
  'alice cannot see bob''s custom exercise');
select is_empty(
  $$update public.exercise set name = 'hacked' where id = '00000000-0000-0000-0000-0000000000e1' returning 1$$,
  'alice cannot update a seeded exercise');
select is_empty(
  $$delete from public.exercise where id = '00000000-0000-0000-0000-0000000000e1' returning 1$$,
  'alice cannot delete a seeded exercise');
select throws_ok(
  $$insert into public.exercise (name, muscle_group, created_by) values ('Fake Seed', 'chest', null)$$,
  '42501', null, 'alice cannot create a seeded-looking exercise (created_by NULL)');
select throws_ok(
  format($$insert into public.exercise (name, muscle_group, created_by) values ('Forged', 'chest', %L)$$, :'bob'),
  '42501', null, 'alice cannot create an exercise owned by bob');
select lives_ok($$insert into public.exercise (name, muscle_group) values ('Mine', 'legs')$$,
  'alice can create her own custom exercise');
select throws_ok(
  $$insert into public.session_exercise (session_id, exercise_id, position)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e3', 9)$$,
  '42501', null, 'alice cannot reference bob''s private exercise');

-- Forged owner / cross-user parents.
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 7, %L, 50, 5)$$, :'bob'),
  '42501', null, 'alice cannot insert a set owned by bob');
select throws_ok(
  format($$insert into public.session_exercise (session_id, user_id, exercise_id, position)
    values ('00000000-0000-0000-0000-0000000000b1', %L, '00000000-0000-0000-0000-0000000000e1', 5)$$, :'alice'),
  '23503', null, 'alice cannot attach an exercise to bob''s session');
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000b2', 5, %L, 50, 5)$$, :'alice'),
  '23503', null, 'alice cannot attach a set to bob''s session exercise');

-- ======================================================================== bob
reset role;
select tests.authenticate_as(:'bob'::uuid);

select is((select count(*) from public.workout_session where id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'bob cannot see alice''s session');
select is((select count(*) from public.session_exercise where session_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'bob cannot see alice''s session exercises');
select is((select count(*) from public.exercise_set where session_exercise_id = '00000000-0000-0000-0000-0000000000a2'), 0::bigint,
  'bob cannot see alice''s sets');
select is((select count(*) from public.exercise where id = '00000000-0000-0000-0000-0000000000e2'), 0::bigint,
  'bob cannot see alice''s custom exercise');
select is_empty(
  $$update public.workout_session set notes = 'hacked' where id = '00000000-0000-0000-0000-0000000000a1' returning 1$$,
  'bob cannot update alice''s session');
select is_empty(
  $$update public.exercise_set set reps = 1 where session_exercise_id = '00000000-0000-0000-0000-0000000000a2' returning 1$$,
  'bob cannot update alice''s sets');
select is_empty(
  $$delete from public.workout_session where id = '00000000-0000-0000-0000-0000000000a1' returning 1$$,
  'bob cannot delete alice''s session');
select throws_ok(
  format($$insert into public.session_exercise (session_id, user_id, exercise_id, position)
    values ('00000000-0000-0000-0000-0000000000a1', %L, '00000000-0000-0000-0000-0000000000e1', 8)$$, :'bob'),
  '23503', null, 'bob cannot attach an exercise to alice''s session even with his own user_id');
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 9, %L, 50, 5)$$, :'bob'),
  '23503', null, 'bob cannot attach a set to alice''s session exercise');

-- Read back as superuser: nothing of alice's changed.
reset role;
select is((select notes from public.workout_session where id = '00000000-0000-0000-0000-0000000000a1'),
  'alice session', 'alice''s session notes are unchanged');
select is((select reps from public.exercise_set
  where session_exercise_id = '00000000-0000-0000-0000-0000000000a2' and set_no = 1), 8,
  'alice''s set is unchanged');
select is((select name from public.exercise where id = '00000000-0000-0000-0000-0000000000e1'),
  'Test Bench Press', 'the seeded exercise is unchanged');

-- ======================================================================== signed out
select tests.authenticate_as_anon();
select throws_ok($$select * from public.exercise$$, '42501', null, 'signed-out select on exercise is denied');
select throws_ok($$select * from public.workout_session$$, '42501', null, 'signed-out select on workout_session is denied');
select throws_ok($$select * from public.session_exercise$$, '42501', null, 'signed-out select on session_exercise is denied');
select throws_ok($$select * from public.exercise_set$$, '42501', null, 'signed-out select on exercise_set is denied');
select throws_ok($$insert into public.workout_session (notes) values ('x')$$, '42501', null, 'signed-out insert is denied');
select throws_ok($$update public.workout_session set notes = 'x'$$, '42501', null, 'signed-out update is denied');
select throws_ok($$delete from public.workout_session$$, '42501', null, 'signed-out delete is denied');

-- ======================================================================== constraints (superuser)
reset role;
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 10, %L, -1, 5)$$, :'alice'),
  '23514', null, 'negative weight is rejected');
select lives_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 11, %L, 0, 5)$$, :'alice'),
  'weight 0 (bodyweight) is accepted');
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 12, %L, 50, 0)$$, :'alice'),
  '23514', null, 'zero reps are rejected');
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 0, %L, 50, 5)$$, :'alice'),
  '23514', null, 'set number 0 is rejected');
select throws_ok(
  format($$insert into public.exercise_set (session_exercise_id, set_no, user_id, weight_kg, reps)
    values ('00000000-0000-0000-0000-0000000000a2', 1, %L, 50, 5)$$, :'alice'),
  '23505', null, 'a duplicate set number is rejected');
select throws_ok(
  format($$insert into public.workout_session (user_id, started_at, ended_at)
    values (%L, now(), now() - interval '1 hour')$$, :'alice'),
  '23514', null, 'a session that ends before it starts is rejected');
select throws_ok(
  format($$insert into public.session_exercise (session_id, user_id, exercise_id, position)
    values ('00000000-0000-0000-0000-0000000000a1', %L, '00000000-0000-0000-0000-0000000000e1', 0)$$, :'alice'),
  '23514', null, 'position 0 is rejected');
select throws_ok(
  $$insert into public.exercise (name, muscle_group) values ('Odd', 'wings')$$,
  '23514', null, 'an unknown muscle group is rejected');
select throws_ok(
  $$insert into public.exercise (name, muscle_group, created_by) values ('test bench press', 'chest', null)$$,
  '23505', null, 'a seeded name cannot be duplicated, ignoring case');
select lives_ok(
  format($$insert into public.exercise (name, muscle_group, created_by) values
    ('Shared Name', 'chest', %L), ('Shared Name', 'chest', %L)$$, :'alice', :'bob'),
  'two users may each have a custom exercise with the same name');

-- ======================================================================== owner immutability
select throws_ok(
  format($$update public.workout_session set user_id = %L where id = '00000000-0000-0000-0000-0000000000a1'$$, :'bob'),
  '42501', 'user_id is immutable', 'a session cannot change owner, even for the superuser');
select throws_ok(
  format($$update public.exercise set created_by = %L where id = '00000000-0000-0000-0000-0000000000e2'$$, :'bob'),
  '42501', 'created_by is immutable', 'an exercise cannot change owner');

-- ======================================================================== cascades
set constraints session_exercise_exercise_id_fkey immediate;
select throws_ok(
  $$delete from public.exercise where id = '00000000-0000-0000-0000-0000000000e2'$$,
  '23503', null, 'a custom exercise that is in use cannot be deleted on its own');
set constraints session_exercise_exercise_id_fkey deferred;
select lives_ok($$delete from public.workout_session where id = '00000000-0000-0000-0000-0000000000a1'$$,
  'deleting a session succeeds');
select is((select count(*) from public.session_exercise where session_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'deleting a session removes its session exercises');
select is((select count(*) from public.exercise_set where session_exercise_id = '00000000-0000-0000-0000-0000000000a2'), 0::bigint,
  'deleting a session removes its sets');

-- Re-add a custom-exercise reference, then delete the whole account.
insert into public.workout_session (id, user_id) values ('00000000-0000-0000-0000-0000000000a5', :'alice');
insert into public.session_exercise (session_id, user_id, exercise_id, position)
  values ('00000000-0000-0000-0000-0000000000a5', :'alice', '00000000-0000-0000-0000-0000000000e2', 1);
select lives_ok(format($$delete from auth.users where id = %L$$, :'alice'),
  'deleting an account succeeds even when her sessions use her custom exercises');
select is((select count(*) from public.workout_session where user_id = :'alice'::uuid), 0::bigint,
  'the account''s sessions are gone');
select is((select count(*) from public.exercise where created_by = :'alice'::uuid), 0::bigint,
  'the account''s custom exercises are gone');
select is((select count(*) from public.workout_session where user_id = :'bob'::uuid), 1::bigint,
  'bob''s data is untouched');
select is((select count(*) from public.exercise where id = '00000000-0000-0000-0000-0000000000e1'), 1::bigint,
  'the seeded exercise survives');

select * from finish();
rollback;
