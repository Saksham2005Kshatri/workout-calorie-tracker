# Data model

Derived from the app flowchart and adjusted while building Phase 2 (see the notes at the end). The migrations in `supabase/migrations/` are the source of truth for exact types and constraints. `?` marks a nullable column. Weights in kg, height in cm, energy in kcal, macros in grams.

## Identity
- **USER** (`users`): id PK/FK to Supabase `auth.users` (cascade), display_name, timezone, is_active, created_at. Created by the Phase 3 sign-up trigger, never by clients.
- **USER_PROFILE** (1-1 USER): id PK/FK, height_cm, birth_date, gender, activity_level, fitness_goal, target_weight_kg?, bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g
- ~~AUTH_IDENTITY, GOOGLE_IDENTITY, PHONE_IDENTITY~~ **dropped**: Supabase Auth already stores providers and verifies OTPs, and we do not want OTP hashes in our own schema. `users` therefore holds no contact data (friend lookup by email will need a deliberate mechanism later).

## Workout
- **EXERCISE**: exercise_id PK, name, muscle_group, equipment?, is_custom, created_by FK? (NULL for seeded library)
- **WORKOUT_SESSION** (USER 1-N): session_id PK, user_id FK, started_at, ended_at?, est_calories_burned, notes?
- **SESSION_EXERCISE** (SESSION 1-N, EXERCISE 1-N): session_exercise_id PK, session_id FK, exercise_id FK, position
- **EXERCISE_SET** (weak, owned by SESSION_EXERCISE): session_exercise_id PK/FK, set_no PK, weight_kg, reps, completed_at

## Nutrition
- **FOOD_ITEM**: food_id PK, name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source
- **MEAL** (USER 1-N): meal_id PK, user_id FK, meal_type, eaten_at, photo_url?, status. Totals are **not stored**: the `meal_totals` view sums the items.
- **MEAL_ITEM** (MEAL 1-N): meal_item_id PK, meal_id FK, food_id FK?, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source (ai|user), user_confirmed

## Body and summary
- **WEIGHT_LOG** (USER 1-N): weight_id PK, user_id FK, weight_kg, logged_on (unique with user_id), created_at
- **DAILY_SUMMARY** (USER 1-N): summary_id PK, user_id FK, summary_date (unique with user_id), calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count, weight_kg?

## Phase 2 adjustments
- `session_exercise`, `exercise_set` and `meal_item` carry their own `user_id`, tied to the parent by a composite foreign key, so policies are one indexed comparison and a child can never point at another user's parent.
- Allowed values (CHECK constraints, not enum types): gender male|female|other; activity_level sedentary|light|moderate|active|very_active; fitness_goal lose_fat|maintain|build_muscle; meal_type breakfast|lunch|dinner|snack; meal status draft|confirmed; meal_item source ai|user; food_item source usda|open_food_facts|user; exercise muscle_group chest|back|shoulders|biceps|triceps|legs|glutes|core|cardio|full_body.
- `exercise` and `food_item`: rows with `created_by` NULL are seeded or imported and read-only to clients; users see those plus their own and write only their own. `is_custom` on `exercise` is derived from `created_by`.
- A session or meal item may only reference an exercise or food the caller can see. `session_exercise.exercise_id` is a deferred foreign key (account deletion cascades in no fixed order); `meal_item.food_item_id` is set to NULL if the food is deleted.
- `daily_summary` is read-only to clients; only the server job writes it. It also stores protein, carbs, fat and weight, as in the model above.
- `source`, `user_confirmed` and meal `status` are set by the client and are not authoritative.
- Clients update rows with their `user_id` unchanged (a trigger rejects owner changes), so upserts work.

## Rules
- Every table gets RLS scoped to `auth.uid()` in the migration that creates it.
- Progressive overload, previous-performance comparison and the weight graph are queries, not tables.
- DAILY_SUMMARY is written at midnight in the user's timezone and snapshots the calorie target.
