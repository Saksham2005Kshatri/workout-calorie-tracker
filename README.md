# Workout & Calorie Tracker

A free workout, nutrition and body-weight tracker for me and my mates. Log lifts (sets, reps, weight), snap meals for AI-estimated macros, track body weight, and see daily progress against calorie goals.

Built with Expo (React Native) and Supabase. See [CLAUDE.md](CLAUDE.md) for the stack, data model, security rules and conventions.

## Layout

- `app/` Expo app
- `supabase/` migrations and Edge Functions
- `docs/` design notes

## Getting started

1. Install Docker, Node and the Supabase CLI.
2. `supabase start` for the local backend, then `supabase test db` to run the database tests.
3. `cd app && npx expo start`.

After changing the schema (a new file in `supabase/migrations/`), run `supabase db reset`, `supabase test db`, then `cd app && npm run gen:types` and commit the regenerated types.

In `app/`, copy `.env.example` to `.env` and fill in values. Never commit `.env`.
