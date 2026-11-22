# Technical TODO

Work top to bottom. Each phase ends with a **Done when** check; do not start the next phase until it passes. Phases are ordered so every phase builds only on things that already exist.

## Phase 0: Accounts and tooling
- [x] Node, Supabase CLI 3.2.0 and EAS CLI 27.11.0 installed
- [x] Docker Desktop running (`docker ps` works)
- [x] Supabase projects created: `workout-dev` (ap-southeast-1) and `workout-prod` (ap-northeast-1); CLI logged in
- [ ] Save both projects' URLs, publishable keys and DB passwords in a password manager
- [ ] Google Cloud project: OAuth consent screen + OAuth client IDs (Web, Android, iOS) for Google sign-in
- [x] Expo account created and `eas login` done (saksham2005kshatri)
- [ ] Get a Gemini API key and a USDA FoodData Central API key (store in a password manager, not in git)
- [ ] Decide iOS route: Apple Developer account ($99/yr, unverified) or PWA fallback
- [ ] Add GitHub secrets: `EXPO_TOKEN`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`
- **Done when:** `supabase --version`, `eas whoami` and `docker ps` all work, and both Supabase projects exist.

## Phase 1: App scaffold
- [x] Scaffold Expo (TypeScript, Expo Router) inside `app/`
- [x] Turn on TypeScript strict; add ESLint and Prettier
- [x] Add scripts: `lint`, `typecheck`, `test`; set up Vitest or Jest
- [x] Add env loading (`EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`) and `.env.example` entries
- [x] Add TanStack Query provider, Zod, and a basic theme (colors, spacing, type)
- [x] Add tab navigation skeleton: Dashboard, Workouts, Nutrition, Weight, Profile
- [ ] Run the app on a real phone via Expo Go
- **Done when:** the app launches on a phone with empty tabs, and the `app` CI job runs and passes.

## Phase 2: Database foundation
- [ ] `supabase init`, link to `workout-dev`, run `supabase start` locally
- [ ] Migration 1, identity: `users` (profile row linked to `auth.users`), `user_profile`, `auth_identity` plus subtypes if still needed alongside Supabase Auth
- [ ] Migration 2, workout: `exercise`, `workout_session`, `session_exercise`, `exercise_set`
- [ ] Migration 3, nutrition: `food_item`, `meal`, `meal_item`
- [ ] Migration 4, body/summary: `weight_log`, `daily_summary` with the unique constraints
- [ ] Enable RLS and write policies on every table in the same migration that creates it
- [ ] Add CHECK constraints (positive weights/reps, valid enums) and indexes on `user_id` + date columns
- [ ] Seed the exercise library (~100 common lifts with muscle group and equipment)
- [ ] Write RLS tests: user A cannot read, insert, update or delete user B's rows on any table
- [ ] Generate TypeScript types from the schema (`supabase gen types`)
- **Done when:** `supabase db reset` applies everything cleanly and the RLS tests pass.

## Phase 3: Authentication
- [ ] Configure Google provider in Supabase (dev project)
- [ ] Supabase client in the app with session storage in `expo-secure-store`
- [ ] Google sign-in screen and sign-out
- [ ] DB trigger: on new `auth.users` row, create the `users` row
- [ ] Route guard: signed-out users see only the login screen
- [ ] Session refresh and handling of expired sessions
- **Done when:** you can sign in with Google on a real phone, see your row in the database, and sign out; a second Google account cannot see your data.

## Phase 4: Onboarding and profile
- [ ] Pure functions with unit tests: BMR (Mifflin-St Jeor), TDEE from activity level, calorie target from fitness goal, macro split
- [ ] Onboarding screens: height, weight, age/birth date, gender, activity level, fitness goal
- [ ] Save `user_profile` with computed targets; first weight goes into `weight_log`
- [ ] Profile screen to edit stats and recalculate targets
- [ ] Dashboard shell with empty cards (weight, workout, calories vs target, macros)
- **Done when:** a new user completes onboarding, targets are correct against hand-calculated examples, and the dashboard shows their targets.

## Phase 5: Weight tracking (simplest full vertical slice)
- [ ] Log weight with date (one per day, editable)
- [ ] Weight history list
- [ ] Progression graph and comparison against the goal weight
- [ ] Dashboard "current body weight" card wired up
- **Done when:** logging weights over several days draws a correct graph and the dashboard card updates.

## Phase 6: Workout tracking
- [ ] Exercise library: search, filter by muscle group, add custom exercise
- [ ] Start session, add exercise, add sets (weight + reps), "add another set / exercise" flow
- [ ] Save session (and handle abandoning or resuming a half-finished one)
- [ ] Workout history list and session detail
- [ ] "Previous performance" shown while logging (last session's sets for that exercise)
- [ ] Progressive overload view per exercise (best set, volume over time)
- [ ] Estimated calories burned (pure function, tested)
- [ ] Dashboard "today's workout progress" card wired up
- **Done when:** you can log a full workout, see last time's numbers while logging, and view progress for a lift.

## Phase 7: Nutrition, manual entry
- [ ] USDA FoodData Central search through an Edge Function (key stays server-side), plus Open Food Facts barcode lookup
- [ ] Add meal with items and portion sizes; compute calories and macros from per-100g values
- [ ] Edit and delete meals and items
- [ ] Daily nutrition log screen with totals
- [ ] Dashboard "calories vs target" and "protein/carbs/fats" cards wired up
- **Done when:** logging three meals by hand shows correct daily totals against your targets.

## Phase 8: AI meal photo
- [ ] Private Storage bucket with a per-user path policy
- [ ] Camera/gallery picker; resize and compress on-device before upload
- [ ] Edge Function `analyze-meal`: verify JWT, per-user rate limit, call Gemini vision, return strict JSON (ingredients with estimated grams)
- [ ] Validate the AI JSON with Zod; handle failures and timeouts gracefully
- [ ] Review screen: confirm ingredients, edit portions, then calories and macros estimated and editable before saving
- [ ] Store `source`, `user_confirmed` on each item
- **Done when:** a photo of a real meal produces a reviewable list, edits are saved, and over-limit or malformed AI responses do not crash the app.

## Phase 9: Daily summary and analytics
- [ ] `generate_daily_summary(user, date)` SQL function (calories, macros, burned, workouts, weight, target snapshot)
- [ ] `pg_cron` job running at each user's local midnight (hourly job that processes users whose day just ended)
- [ ] Idempotent: rerunning for a date updates, never duplicates
- [ ] View daily summary screen
- [ ] Historical reports and analytics: weekly/monthly trends, calories vs target adherence, weight trend
- **Done when:** a simulated midnight run creates correct summaries, a second run changes nothing, and history charts match the raw data.

## Phase 10: Offline and polish
- [ ] Local cache with `expo-sqlite` for exercises, recent sessions, and today's data
- [ ] Offline write queue for sets, meals and weight, synced on reconnect with conflict rules
- [ ] Loading, empty and error states on every screen
- [ ] Input validation messages, unit handling (kg/lb display only), accessibility labels
- [ ] App icon, splash screen, app name
- **Done when:** you can log a workout in airplane mode and it syncs correctly afterwards.

## Phase 11: Security and quality gate
- [ ] RLS audit: list every table and confirm RLS is on with tested policies
- [ ] Confirm no secret or `service_role` key in the app bundle or git history (gitleaks full scan)
- [ ] Verify every Edge Function checks the JWT and rate-limits
- [ ] Add Sentry (free tier) with PII scrubbing
- [ ] End-to-end tests with Maestro for onboarding, log workout, log meal, log weight
- [ ] Dependency audit (`npm audit`) and fix high-severity items
- [ ] Privacy basics: delete-my-account (removes all rows and photos), a short privacy note for your mates
- **Done when:** the checklist is clean and the e2e suite passes on a real device.

## Phase 12: Deployment and rollout
- [ ] Link `workout-prod`; push migrations; deploy Edge Functions; set production secrets
- [ ] Configure Google provider on prod; add a keep-alive ping so the free project does not pause
- [ ] EAS build profiles (`development`, `preview`, `production`); first Android APK
- [ ] iOS: TestFlight (if Apple account) or PWA build hosted on Cloudflare Pages/Vercel
- [ ] GitHub Actions CD: migrations and functions on merge to `main`, `eas update` for JS changes
- [ ] Install on one friend's phone and run through every flow against prod
- [ ] Invite the rest; set up a place to collect bug reports
- **Done when:** your mates are using the production app and a JS fix reaches their phones via `eas update`.

## Later (not designed yet; ask before building)
- [ ] Phone number + OTP sign-in (costs money per SMS; add CAPTCHA and rate limits)
- [ ] Friends and progress sharing (`FRIENDSHIP` table, RLS for shared reads)
- [ ] Notifications (workout reminders, log-your-weight nudges)
- [ ] Data export (CSV)
