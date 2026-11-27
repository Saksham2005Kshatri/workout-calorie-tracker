-- food_item / meal / meal_item / meal_totals: RLS, derived totals, reference visibility,
-- constraints, immutability, cascades.
begin;
select plan(58);

select tests.create_user('alice@example.test') as alice \gset
select tests.create_user('bob@example.test') as bob \gset

-- Fixtures (superuser).
insert into public.food_item (id, name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source, created_by) values
  ('00000000-0000-0000-0000-0000000000f1', 'Test Rice', 130, 2.7, 28, 0.3, 'usda', null),
  ('00000000-0000-0000-0000-0000000000f2', 'Alice Food', 100, 10, 10, 1, 'user', :'alice'),
  ('00000000-0000-0000-0000-0000000000f3', 'Bob Food', 100, 10, 10, 1, 'user', :'bob');

insert into public.meal (id, user_id, meal_type) values
  ('00000000-0000-0000-0000-0000000000a1', :'alice', 'lunch'),
  ('00000000-0000-0000-0000-0000000000a2', :'alice', 'snack'),   -- empty meal
  ('00000000-0000-0000-0000-0000000000b1', :'bob', 'dinner');
insert into public.meal_item (id, meal_id, user_id, food_item_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source) values
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a1', :'alice', '00000000-0000-0000-0000-0000000000f1', 'rice', 200, 100, 10, 20, 1, 'user'),
  ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000a1', :'alice', '00000000-0000-0000-0000-0000000000f2', 'mine', 100, 200, 20, 30, 2, 'user'),
  ('00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000a1', :'alice', null, 'chicken', 150, 300, 30, 0, 3, 'ai'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000b1', :'bob', null, 'steak', 200, 500, 50, 0, 20, 'user');

-- ======================================================================== alice
select tests.authenticate_as(:'alice'::uuid);

select is((select count(*) from public.meal), 2::bigint, 'alice sees only her meals');
select is((select count(*) from public.meal_item), 3::bigint, 'alice sees only her meal items');
select is((select count(*) from public.meal_totals), 2::bigint, 'the totals view shows only her meals');
select results_eq(
  $$select total_calories, total_protein_g, total_carbs_g, total_fat_g from public.meal_totals
    where meal_id = '00000000-0000-0000-0000-0000000000a1'$$,
  $$values (600.00::numeric, 60.00::numeric, 50.00::numeric, 6.00::numeric)$$,
  'three items sum to the right totals');
select results_eq(
  $$select total_calories, total_protein_g from public.meal_totals
    where meal_id = '00000000-0000-0000-0000-0000000000a2'$$,
  $$values (0.00::numeric, 0.00::numeric)$$,
  'a meal with no items has zero totals (and still a row)');
select lives_ok(
  $$insert into public.meal_item (meal_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a2', 'apple', 100, 50, 0, 12, 0, 'user')$$,
  'alice can add an item to her empty meal');
select is((select total_calories from public.meal_totals where meal_id = '00000000-0000-0000-0000-0000000000a2'),
  50.00::numeric, 'the totals update immediately');
select lives_ok(
  $$update public.meal_item set calories = 60 where meal_id = '00000000-0000-0000-0000-0000000000a2'$$,
  'alice can edit an item');
select lives_ok(
  $$delete from public.meal_item where meal_id = '00000000-0000-0000-0000-0000000000a2'$$,
  'alice can delete an item');
select is((select total_calories from public.meal_totals where meal_id = '00000000-0000-0000-0000-0000000000a2'),
  0.00::numeric, 'totals drop back to zero');
select lives_ok($$insert into public.meal (meal_type) values ('breakfast')$$,
  'alice can create a meal (user_id defaults to her)');
select lives_ok(
  format($$insert into public.meal (meal_type, photo_url) values ('breakfast', %L)$$, :'alice' || '/photo.jpg'),
  'a photo path inside her own folder is accepted');
select throws_ok(
  format($$insert into public.meal (meal_type, photo_url) values ('breakfast', %L)$$, :'bob' || '/photo.jpg'),
  '23514', null, 'a photo path inside another user''s folder is rejected');

-- Reference data.
select is((select count(*) from public.food_item where id = '00000000-0000-0000-0000-0000000000f1'), 1::bigint,
  'alice sees the seeded food');
select is((select count(*) from public.food_item where id = '00000000-0000-0000-0000-0000000000f2'), 1::bigint,
  'alice sees her own custom food');
select is((select count(*) from public.food_item where id = '00000000-0000-0000-0000-0000000000f3'), 0::bigint,
  'alice cannot see bob''s custom food');
select is_empty(
  $$update public.food_item set name = 'hacked' where id = '00000000-0000-0000-0000-0000000000f1' returning 1$$,
  'alice cannot update a seeded food');
select is_empty(
  $$delete from public.food_item where id = '00000000-0000-0000-0000-0000000000f1' returning 1$$,
  'alice cannot delete a seeded food');
select throws_ok(
  $$insert into public.food_item (name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source, created_by)
    values ('Fake', 1, 1, 1, 1, 'usda', null)$$,
  '42501', null, 'alice cannot create a seeded-looking food (created_by NULL)');
select throws_ok(
  $$insert into public.food_item (name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source)
    values ('Fake', 1, 1, 1, 1, 'usda')$$,
  '23514', null, 'alice cannot label her own food as usda');
select throws_ok(
  format($$insert into public.food_item (name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source, created_by)
    values ('Forged', 1, 1, 1, 1, 'user', %L)$$, :'bob'),
  '42501', null, 'alice cannot create a food owned by bob');
select lives_ok(
  $$insert into public.food_item (name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source)
    values ('Water', 0, 0, 0, 0, 'user')$$,
  'alice can create a custom food, zero values included');
select throws_ok(
  $$insert into public.meal_item (meal_id, food_item_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f3', 'x', 100, 1, 1, 1, 1, 'user')$$,
  '42501', null, 'alice cannot link her item to bob''s private food');

-- Cross-user parents.
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000b1', %L, 'x', 100, 1, 1, 1, 1, 'user')$$, :'alice'),
  '23503', null, 'alice cannot attach an item to bob''s meal');
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', %L, 'x', 100, 1, 1, 1, 1, 'user')$$, :'bob'),
  '42501', null, 'alice cannot insert an item owned by bob');

-- ======================================================================== bob
reset role;
select tests.authenticate_as(:'bob'::uuid);

select is((select count(*) from public.meal where id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'bob cannot see alice''s meal');
select is((select count(*) from public.meal_item where meal_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'bob cannot see alice''s items');
select is((select count(*) from public.meal_totals where meal_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'bob cannot see alice''s totals through the view');
select is_empty(
  $$update public.meal set status = 'confirmed' where id = '00000000-0000-0000-0000-0000000000a1' returning 1$$,
  'bob cannot update alice''s meal');
select is_empty(
  $$update public.meal_item set calories = 1 where meal_id = '00000000-0000-0000-0000-0000000000a1' returning 1$$,
  'bob cannot update alice''s items');
select is_empty(
  $$delete from public.meal where id = '00000000-0000-0000-0000-0000000000a1' returning 1$$,
  'bob cannot delete alice''s meal');
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', %L, 'x', 100, 1, 1, 1, 1, 'user')$$, :'bob'),
  '23503', null, 'bob cannot attach an item to alice''s meal even with his own user_id');

reset role;
select is((select status from public.meal where id = '00000000-0000-0000-0000-0000000000a1'), 'draft',
  'alice''s meal status is unchanged');
select is((select calories from public.meal_item where id = '00000000-0000-0000-0000-0000000000a3'), 100.00::numeric,
  'alice''s item is unchanged');

-- ======================================================================== signed out
select tests.authenticate_as_anon();
select throws_ok($$select * from public.food_item$$, '42501', null, 'signed-out select on food_item is denied');
select throws_ok($$select * from public.meal$$, '42501', null, 'signed-out select on meal is denied');
select throws_ok($$select * from public.meal_item$$, '42501', null, 'signed-out select on meal_item is denied');
select throws_ok($$select * from public.meal_totals$$, '42501', null, 'signed-out select on the totals view is denied');
select throws_ok($$insert into public.meal (meal_type) values ('lunch')$$, '42501', null, 'signed-out insert is denied');
select throws_ok($$update public.meal set status = 'confirmed'$$, '42501', null, 'signed-out update is denied');
select throws_ok($$delete from public.meal$$, '42501', null, 'signed-out delete is denied');

-- ======================================================================== constraints (superuser)
reset role;
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', %L, 'x', 0, 1, 1, 1, 1, 'user')$$, :'alice'),
  '23514', null, 'a zero portion is rejected');
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', %L, 'x', 100, -1, 1, 1, 1, 'user')$$, :'alice'),
  '23514', null, 'negative calories are rejected');
select throws_ok(
  format($$insert into public.meal_item (meal_id, user_id, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source)
    values ('00000000-0000-0000-0000-0000000000a1', %L, 'x', 100, 1, 1, 1, 1, 'robot')$$, :'alice'),
  '23514', null, 'an unknown item source is rejected');
select throws_ok(
  $$insert into public.food_item (name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source, created_by)
    values ('Impossible', 100, 60, 60, 10, 'usda', null)$$,
  '23514', null, 'macros summing over 100 g per 100 g are rejected');
select throws_ok(
  format($$insert into public.meal (user_id, meal_type) values (%L, 'brunch')$$, :'alice'),
  '23514', null, 'an unknown meal type is rejected');
select throws_ok(
  format($$insert into public.meal (user_id, meal_type, status) values (%L, 'lunch', 'done')$$, :'alice'),
  '23514', null, 'an unknown meal status is rejected');

-- ======================================================================== owner immutability
select throws_ok(
  format($$update public.meal set user_id = %L where id = '00000000-0000-0000-0000-0000000000a1'$$, :'bob'),
  '42501', 'user_id is immutable', 'a meal cannot change owner');

-- ======================================================================== cascades
select lives_ok($$delete from public.food_item where id = '00000000-0000-0000-0000-0000000000f2'$$,
  'deleting a custom food that an item uses succeeds');
select is((select food_item_id from public.meal_item where id = '00000000-0000-0000-0000-0000000000a4'), null::uuid,
  'the item keeps its values but loses the food link');
select is((select calories from public.meal_item where id = '00000000-0000-0000-0000-0000000000a4'), 200.00::numeric,
  'the item''s own calories are untouched');
select lives_ok($$delete from public.meal where id = '00000000-0000-0000-0000-0000000000a1'$$,
  'deleting a meal succeeds');
select is((select count(*) from public.meal_item where meal_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint,
  'deleting a meal removes its items');
select lives_ok(format($$delete from auth.users where id = %L$$, :'alice'), 'deleting an account succeeds');
select is((select count(*) from public.meal where user_id = :'alice'::uuid), 0::bigint, 'the account''s meals are gone');
select is((select count(*) from public.food_item where created_by = :'alice'::uuid), 0::bigint,
  'the account''s custom foods are gone');
select is((select count(*) from public.meal where user_id = :'bob'::uuid), 1::bigint, 'bob''s meals are untouched');
select is((select count(*) from public.food_item where id = '00000000-0000-0000-0000-0000000000f1'), 1::bigint,
  'the seeded food survives');

select * from finish();
rollback;
