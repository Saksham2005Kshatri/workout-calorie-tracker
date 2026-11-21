# Workout & Calorie Tracker

A free workout, nutrition and body-weight tracker for me and my mates. Log lifts (sets, reps, weight), snap meals for AI-estimated macros, track body weight, and see daily progress against calorie goals.

Built with Expo (React Native) and Supabase. See [CLAUDE.md](CLAUDE.md) for the stack, data model, security rules and conventions.

## Layout

- `app/` Expo app
- `supabase/` migrations and Edge Functions
- `docs/` design notes

## Getting started

Not scaffolded yet. Planned flow:

1. Install Docker, Node and the Supabase CLI.
2. `supabase start` for the local backend.
3. `cd app && npx expo start`.

Copy `.env.example` to `.env` and fill in values. Never commit `.env`.
