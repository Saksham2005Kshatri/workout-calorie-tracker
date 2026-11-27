-- Workout: exercise library and workout logging (plan U3).
-- Child tables carry user_id tied to the parent by composite FKs (KTD2, KTD14), so a
-- child can never point at another user's parent and policies are one indexed comparison.

-- exercise: seeded library (created_by NULL, read-only to clients) plus a user's custom rows.
create table public.exercise (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  muscle_group text not null check (muscle_group in (
    'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'glutes', 'core', 'cardio', 'full_body'
  )),
  equipment text check (equipment in (
    'barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'kettlebell', 'band', 'other'
  )),
  created_by uuid default auth.uid() references public.users (id) on delete cascade,
  -- Derived, so a client can never claim a row is seeded (or custom).
  is_custom boolean generated always as (created_by is not null) stored
);
-- Seeded names are unique (backs the idempotent seed in a later migration); custom rows may repeat.
create unique index exercise_seeded_name_key on public.exercise (lower(name)) where created_by is null;
create index exercise_created_by_idx on public.exercise (created_by);
create index exercise_muscle_group_idx on public.exercise (muscle_group);

create table public.workout_session (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  est_calories_burned numeric(7, 1) not null default 0
    check (est_calories_burned >= 0 and est_calories_burned <= 20000),
  notes text check (char_length(notes) <= 2000),
  constraint workout_session_ended_after_start check (ended_at is null or ended_at >= started_at),
  constraint workout_session_id_user_key unique (id, user_id)
);
create index workout_session_user_started_idx on public.workout_session (user_id, started_at desc);

create table public.session_exercise (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  user_id uuid not null default auth.uid(),
  -- Deferred: when an account is deleted, its custom exercises and the sessions using them
  -- cascade in no fixed order, so the check must wait until the whole statement is done.
  exercise_id uuid not null references public.exercise (id) deferrable initially deferred,
  position integer not null check (position > 0 and position <= 200),
  constraint session_exercise_session_fk foreign key (session_id, user_id)
    references public.workout_session (id, user_id) on delete cascade,
  constraint session_exercise_id_user_key unique (id, user_id),
  -- Deferred so exercises can be reordered inside one transaction.
  constraint session_exercise_position_key unique (session_id, position) deferrable initially deferred
);
create index session_exercise_user_idx on public.session_exercise (user_id);
create index session_exercise_session_idx on public.session_exercise (session_id);
create index session_exercise_exercise_idx on public.session_exercise (exercise_id);

-- Weak entity: identified by its parent plus the set number.
create table public.exercise_set (
  session_exercise_id uuid not null,
  set_no integer not null check (set_no > 0 and set_no <= 200),
  user_id uuid not null default auth.uid(),
  weight_kg numeric(6, 2) not null check (weight_kg >= 0 and weight_kg <= 1000), -- 0 = bodyweight
  reps integer not null check (reps > 0 and reps <= 1000),
  completed_at timestamptz not null default now(),
  primary key (session_exercise_id, set_no),
  constraint exercise_set_parent_fk foreign key (session_exercise_id, user_id)
    references public.session_exercise (id, user_id) on delete cascade
);
create index exercise_set_user_idx on public.exercise_set (user_id);

-- Owner immutability (KTD5).
create trigger exercise_forbid_owner_change before update on public.exercise
  for each row execute function private.forbid_owner_change();
create trigger workout_session_forbid_owner_change before update on public.workout_session
  for each row execute function private.forbid_owner_change();
create trigger session_exercise_forbid_owner_change before update on public.session_exercise
  for each row execute function private.forbid_owner_change();
create trigger exercise_set_forbid_owner_change before update on public.exercise_set
  for each row execute function private.forbid_owner_change();

alter table public.exercise enable row level security;
alter table public.workout_session enable row level security;
alter table public.session_exercise enable row level security;
alter table public.exercise_set enable row level security;

revoke all on public.exercise, public.workout_session, public.session_exercise, public.exercise_set
  from anon, authenticated;
grant select, insert, update, delete
  on public.exercise, public.workout_session, public.session_exercise, public.exercise_set
  to authenticated;

-- exercise: everyone reads seeded + own; clients write only their own custom rows (KTD6).
create policy exercise_select on public.exercise
  for select to authenticated using (created_by is null or created_by = (select auth.uid()));
create policy exercise_insert on public.exercise
  for insert to authenticated with check (created_by = (select auth.uid()));
create policy exercise_update on public.exercise
  for update to authenticated
  using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));
create policy exercise_delete on public.exercise
  for delete to authenticated using (created_by = (select auth.uid()));

-- Owner-only tables.
create policy workout_session_select on public.workout_session
  for select to authenticated using (user_id = (select auth.uid()));
create policy workout_session_insert on public.workout_session
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy workout_session_update on public.workout_session
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy workout_session_delete on public.workout_session
  for delete to authenticated using (user_id = (select auth.uid()));

-- session_exercise: also requires the referenced exercise to be visible to the caller (KTD12).
-- The foreign-key check bypasses RLS; this subquery runs under the caller's RLS on exercise,
-- so another user's private exercise is invisible and the insert is rejected.
create policy session_exercise_select on public.session_exercise
  for select to authenticated using (user_id = (select auth.uid()));
create policy session_exercise_insert on public.session_exercise
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.exercise e where e.id = exercise_id));
create policy session_exercise_update on public.session_exercise
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.exercise e where e.id = exercise_id));
create policy session_exercise_delete on public.session_exercise
  for delete to authenticated using (user_id = (select auth.uid()));

create policy exercise_set_select on public.exercise_set
  for select to authenticated using (user_id = (select auth.uid()));
create policy exercise_set_insert on public.exercise_set
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy exercise_set_update on public.exercise_set
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy exercise_set_delete on public.exercise_set
  for delete to authenticated using (user_id = (select auth.uid()));
