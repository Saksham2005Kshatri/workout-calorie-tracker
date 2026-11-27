-- Body and summary: weight log and read-only daily summaries (plan U5).

create table public.weight_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  weight_kg numeric(5, 2) not null check (weight_kg > 0 and weight_kg <= 700),
  -- UTC day by default; the app sends the user's local day explicitly.
  logged_on date not null default current_date,
  created_at timestamptz not null default now(),
  -- One entry per user per day; also the upsert key for same-day edits and offline sync.
  constraint weight_log_user_day_key unique (user_id, logged_on)
);

-- daily_summary: a snapshot written at the end of each user's day by a server job (Phase 9).
-- Clients can only read it. Targets are copied so later goal changes never rewrite history.
create table public.daily_summary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  summary_date date not null,
  calories_in numeric(8, 2) not null check (calories_in >= 0),
  protein_g numeric(8, 2) not null check (protein_g >= 0),
  carbs_g numeric(8, 2) not null check (carbs_g >= 0),
  fat_g numeric(8, 2) not null check (fat_g >= 0),
  calories_burned numeric(8, 2) not null check (calories_burned >= 0),
  calorie_target numeric(7, 2) not null check (calorie_target >= 0),
  workout_count integer not null check (workout_count >= 0),
  weight_kg numeric(5, 2) check (weight_kg > 0 and weight_kg <= 700),
  constraint daily_summary_user_date_key unique (user_id, summary_date)
);

create trigger weight_log_forbid_owner_change before update on public.weight_log
  for each row execute function private.forbid_owner_change();

alter table public.weight_log enable row level security;
alter table public.daily_summary enable row level security;

revoke all on public.weight_log, public.daily_summary from anon, authenticated;
grant select, insert, update, delete on public.weight_log to authenticated;
grant select on public.daily_summary to authenticated; -- read-only; the server job writes it

create policy weight_log_select on public.weight_log
  for select to authenticated using (user_id = (select auth.uid()));
create policy weight_log_insert on public.weight_log
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy weight_log_update on public.weight_log
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy weight_log_delete on public.weight_log
  for delete to authenticated using (user_id = (select auth.uid()));

create policy daily_summary_select on public.daily_summary
  for select to authenticated using (user_id = (select auth.uid()));
