-- users / user_profile: RLS, grants, constraints, owner immutability, delete cascade.
begin;
select plan(28);

select tests.create_user('alice@example.test') as alice \gset
select tests.create_user('bob@example.test') as bob \gset
select tests.create_user('carol@example.test') as carol \gset

-- Fixtures (superuser): profiles for alice and bob. carol has none yet.
insert into public.user_profile
  (id, height_cm, birth_date, gender, activity_level, fitness_goal,
   bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g)
values
  (:'alice', 170, '1990-01-01', 'female', 'moderate', 'maintain', 1400, 2000, 120, 220, 60),
  (:'bob',   180, '1992-02-02', 'male',   'active',   'build_muscle', 1800, 2800, 180, 300, 80);

-- ---------------------------------------------------------------- alice (owner)
select tests.authenticate_as(:'alice'::uuid);

select is((select count(*) from public.users), 1::bigint, 'alice sees only her own users row');
select is((select count(*) from public.user_profile), 1::bigint, 'alice sees only her own profile');
select lives_ok(
  format($$update public.users set display_name = 'Alice2' where id = %L$$, :'alice'),
  'alice can update her own users row');
select is((select display_name from public.users where id = :'alice'::uuid), 'Alice2',
  'the update is visible to her');
select lives_ok(
  format($$update public.user_profile set height_cm = 171 where id = %L$$, :'alice'),
  'alice can update her own profile');
select throws_ok(
  format($$insert into public.users (id, display_name) values (%L, 'x')$$, :'carol'),
  '42501', null, 'clients cannot insert users rows');
select throws_ok(
  format($$delete from public.users where id = %L$$, :'alice'),
  '42501', null, 'clients cannot delete users rows');
select throws_ok(
  format($$insert into public.user_profile
    (id, height_cm, birth_date, gender, activity_level, fitness_goal,
     bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g)
    values (%L, 170, '1990-01-01', 'male', 'light', 'maintain', 1500, 2000, 100, 200, 60)$$, :'carol'),
  '42501', null, 'alice cannot create a profile for another user');

-- ---------------------------------------------------------------- bob (other user)
reset role;
select tests.authenticate_as(:'bob'::uuid);

select is((select count(*) from public.users where id = :'alice'::uuid), 0::bigint,
  'bob cannot see alice''s users row');
select is((select count(*) from public.user_profile where id = :'alice'::uuid), 0::bigint,
  'bob cannot see alice''s profile');
select is_empty(
  format($$update public.users set display_name = 'hacked' where id = %L returning 1$$, :'alice'),
  'bob''s update of alice''s users row touches nothing');
select is_empty(
  format($$update public.user_profile set height_cm = 1 where id = %L returning 1$$, :'alice'),
  'bob''s update of alice''s profile touches nothing');

-- Prove the attempts changed nothing (read back as superuser).
reset role;
select is((select display_name from public.users where id = :'alice'::uuid), 'Alice2',
  'alice''s display name is unchanged after bob''s attempt');
select is((select height_cm from public.user_profile where id = :'alice'::uuid), 171.0::numeric,
  'alice''s height is unchanged after bob''s attempt');

-- ---------------------------------------------------------------- signed out
select tests.authenticate_as_anon();
select throws_ok($$select * from public.users$$, '42501', null, 'signed-out select on users is denied');
select throws_ok($$select * from public.user_profile$$, '42501', null,
  'signed-out select on user_profile is denied');
select throws_ok(
  format($$insert into public.user_profile
    (id, height_cm, birth_date, gender, activity_level, fitness_goal,
     bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g)
    values (%L, 170, '1990-01-01', 'male', 'light', 'maintain', 1500, 2000, 100, 200, 60)$$, :'carol'),
  '42501', null, 'signed-out insert is denied');

-- ---------------------------------------------------------------- constraints (superuser)
reset role;
select throws_ok(
  format($$update public.user_profile set height_cm = 0 where id = %L$$, :'alice'),
  '23514', null, 'height 0 is rejected');
select throws_ok(
  format($$update public.user_profile set daily_calorie_target = -1 where id = %L$$, :'alice'),
  '23514', null, 'negative calorie target is rejected');
select throws_ok(
  format($$update public.user_profile set gender = 'robot' where id = %L$$, :'alice'),
  '23514', null, 'unknown gender is rejected');
select throws_ok(
  format($$update public.users set timezone = '' where id = %L$$, :'alice'),
  '23514', null, 'empty timezone is rejected');
select throws_ok(
  format($$update public.user_profile set birth_date = '1800-01-01' where id = %L$$, :'alice'),
  '23514', null, 'out-of-range birth date is rejected');
select lives_ok(
  format($$insert into public.user_profile
    (id, height_cm, birth_date, gender, activity_level, fitness_goal,
     bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g)
    values (%L, 0.1, '1900-01-01', 'other', 'very_active', 'lose_fat', 0, 0, 0, 0, 0)$$, :'carol'),
  'boundary-valid values are accepted');

-- ---------------------------------------------------------------- owner immutability
select throws_ok(
  format($$update public.user_profile set id = %L where id = %L$$, :'carol', :'alice'),
  '42501', 'id is immutable', 'the owner id can never change, even for the superuser');

-- ---------------------------------------------------------------- cascade
select lives_ok(
  format($$delete from auth.users where id = %L$$, :'alice'), 'deleting the auth user succeeds');
select is((select count(*) from public.users where id = :'alice'::uuid), 0::bigint,
  'the users row is removed with the auth user');
select is((select count(*) from public.user_profile where id = :'alice'::uuid), 0::bigint,
  'the profile row is removed with the auth user');
select is((select count(*) from public.users where id = :'bob'::uuid), 1::bigint,
  'other users are untouched by the cascade');

select * from finish();
rollback;
