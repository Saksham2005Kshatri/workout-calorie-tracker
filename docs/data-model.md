# Data model

Derived from the app flowchart. `?` marks a nullable column. Weights in kg, height in cm, energy in kcal, macros in grams.

## Identity
- **USER**: user_id PK, display_name, timezone, is_active, created_at
- **USER_PROFILE** (1-1 USER): user_id PK/FK, height_cm, birth_date, gender, activity_level, fitness_goal, target_weight_kg?, bmr_kcal, daily_calorie_target, protein_target_g, carb_target_g, fat_target_g
- **AUTH_IDENTITY** (USER 1-N): identity_id PK, user_id FK, provider (google|phone), created_at
  - **GOOGLE_IDENTITY** (disjoint, total subtype): identity_id PK/FK, google_sub, email
  - **PHONE_IDENTITY** (disjoint, total subtype): identity_id PK/FK, phone_e164, otp_hash, otp_expires_at, verified_at?

## Workout
- **EXERCISE**: exercise_id PK, name, muscle_group, equipment?, is_custom, created_by FK? (NULL for seeded library)
- **WORKOUT_SESSION** (USER 1-N): session_id PK, user_id FK, started_at, ended_at?, est_calories_burned, notes?
- **SESSION_EXERCISE** (SESSION 1-N, EXERCISE 1-N): session_exercise_id PK, session_id FK, exercise_id FK, position
- **EXERCISE_SET** (weak, owned by SESSION_EXERCISE): session_exercise_id PK/FK, set_no PK, weight_kg, reps, completed_at

## Nutrition
- **FOOD_ITEM**: food_id PK, name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source
- **MEAL** (USER 1-N): meal_id PK, user_id FK, meal_type, eaten_at, photo_url?, status, total_calories, total_protein_g, total_carbs_g, total_fat_g
- **MEAL_ITEM** (MEAL 1-N): meal_item_id PK, meal_id FK, food_id FK?, ingredient_name, portion_g, calories, protein_g, carbs_g, fat_g, source (ai|user), user_confirmed

## Body and summary
- **WEIGHT_LOG** (USER 1-N): weight_id PK, user_id FK, weight_kg, logged_on (unique with user_id), created_at
- **DAILY_SUMMARY** (USER 1-N): summary_id PK, user_id FK, summary_date (unique with user_id), calories_in, protein_g, carbs_g, fat_g, calories_burned, calorie_target, workout_count, weight_kg?

## Rules
- Every table gets RLS scoped to `auth.uid()` in the migration that creates it.
- Progressive overload, previous-performance comparison and the weight graph are queries, not tables.
- DAILY_SUMMARY is written at midnight in the user's timezone and snapshots the calorie target.
