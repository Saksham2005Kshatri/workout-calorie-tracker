# Workout & Calorie Tracker

Free, private workout / nutrition / body-weight tracker for the owner and a few friends. Runs on iOS and Android. No ads, no paywall. Keep running costs at or near $0.

Repo: https://github.com/Saksham2005Kshatri/workout-calorie-tracker

## Status

Phase 1 complete: Expo SDK 58 app shell in `app/` (five placeholder tabs, env validation, query provider, light/dark theme, lint/typecheck/jest), verified in Expo Go, CI green. Phase 2 complete: full schema with RLS in `supabase/migrations/`, 104 seeded exercises, generated types, and a pgTAP suite run by CI; applied to `workout-dev` (not `workout-prod`). Next: Phase 3, auth. Auth is not started. Build order lives in `docs/TODO.md`: work through it phase by phase, tick items off as they land, and do not start a phase before the previous one's "Done when" passes. Update this section as milestones land.

## Stack (decided)

| Layer | Choice |
|---|---|
| App | Expo + React Native + TypeScript, Expo Router |
| Data/state | TanStack Query, Zod for validation, `expo-sqlite` for offline cache (gym signal is bad) |
| Backend | Supabase: Postgres, Auth (Google first, phone OTP later), Storage, Edge Functions, `pg_cron` |
| AI | Meal-photo analysis in a Supabase Edge Function calling a Gemini Flash vision model (structured JSON out) |
| Food data | USDA FoodData Central, Open Food Facts (barcodes) |
| CI/CD | GitHub Actions, EAS Build, EAS Update |

Do not swap the stack (e.g. to Firebase or Flutter) without asking. The data model is relational on purpose.

## Repo layout

```
app/                  Expo app (to be scaffolded here)
supabase/migrations/  SQL migrations, the only way schema changes
supabase/functions/   Edge Functions (e.g. analyze-meal)
docs/                 Architecture and data model notes
.github/workflows/    CI
```

## Commands

Planned; confirm they exist before relying on them.

```
supabase start                 # local Postgres/Auth/Storage in Docker
supabase test db               # pgTAP: RLS, constraints, schema guards (needs supabase start)
cd app && npm run gen:types    # regenerate app/src/lib/database.types.ts after a schema change
supabase db reset              # re-apply all migrations + seed locally
supabase db push               # apply migrations to the linked remote project
supabase functions deploy <n>  # deploy one Edge Function
cd app && npx expo start       # run the app (needs app/.env, copy from app/.env.example)
cd app && npm run lint && npm run typecheck && npm test
eas build --platform android --profile preview
eas update                     # OTA JS update
```

## Data model

Source of truth is the EERD plus `docs/data-model.md`. Summary:

- Identity: `users` (id = Supabase auth user id) 1-1 `user_profile`. There is no `AUTH_IDENTITY` table: Supabase Auth owns providers and OTP.
- Workout: `WORKOUT_SESSION` 1-N `SESSION_EXERCISE` N-1 `EXERCISE`; `SESSION_EXERCISE` 1-N `EXERCISE_SET` (weak entity, key `(session_exercise_id, set_no)`). Seeded exercises have `created_by` NULL.
- Nutrition: `MEAL` 1-N `MEAL_ITEM`; `MEAL_ITEM` optionally references `FOOD_ITEM`. Meal totals come from the `meal_totals` view, never stored. `MEAL_ITEM.source` is `ai` or `user`; `user_confirmed` records the confirm step.
- Body/summary: `WEIGHT_LOG` (unique `user_id, logged_on`); `DAILY_SUMMARY` (unique `user_id, summary_date`).
- Progressive overload, previous-performance comparison, weight graph and "vs goal" are computed by queries. Do not add tables for them.
- `DAILY_SUMMARY` is a snapshot written by a `pg_cron` job at midnight in the user's `timezone`. It copies `calorie_target` so goal changes never rewrite history.

## Security rules (non-negotiable)

1. Every table has RLS enabled in the same migration that creates it. Policies scope rows to `auth.uid()`. A table without policies is a bug.
2. Only the Supabase publishable (anon) key may appear in the app. Never put the `service_role` key, AI keys or any secret in the client, in git, or in `EXPO_PUBLIC_*` variables.
3. Third-party API calls (Gemini, USDA) go through Edge Functions that verify the caller's JWT and rate-limit per user. Keys live in `supabase secrets`.
4. Session tokens go in `expo-secure-store`, not AsyncStorage.
5. Meal photos live in a private Storage bucket with a per-user path policy. Resize on-device before upload (free tier is ~1 GB).
6. Validate all external input with Zod, on the client and again in Edge Functions.
7. Never commit `.env` files. Only `.env.example` with placeholder values.
8. Treat AI output as untrusted: validate its JSON against a schema and let the user confirm before saving.

## Conventions

- TypeScript strict mode. No `any` without a comment explaining why.
- Schema changes only via new files in `supabase/migrations/` (`supabase migration new <name>`). Never edit an applied migration and never change the remote schema from the dashboard.
- Units: store weight in kg, height in cm, energy in kcal, macros in grams. Convert only at the UI edge.
- Timestamps are `timestamptz` in UTC. "Day" boundaries use the user's `timezone`.
- Logic with real rules (BMR, calorie targets, daily rollups, overload comparison) lives in pure functions with unit tests, not inside components.
- Keep components small; screens fetch via TanStack Query hooks, not inline `supabase` calls.
- Only screens and layouts go in `app/src/app/` (every file there becomes a route). Tests live in `app/src/__tests__/` or next to code outside that folder, never inside it.
- Conventional commit messages (`feat:`, `fix:`, `chore:`, `docs:`).
- Work on feature branches and open PRs into `main`; do not push directly to `main` once CI exists.

## Working agreements for Claude

- Prefer the smallest change that solves the task. Do not add features, tables or dependencies that were not asked for.
- Ask before: changing the stack, adding a paid service, running destructive database commands, or pushing/deploying.
- Run lint, typecheck and tests before saying work is done, and report failures plainly.
- Never run `supabase db push`, `functions deploy` or `eas` against the production project without explicit approval.
- Not yet designed: friend sharing (a `FRIENDSHIP(user_id, friend_id, status)` table is the likely shape), phone OTP sign-in (costs money per SMS), iOS distribution (needs Apple Developer account or a PWA fallback). Ask before building any of these.
