-- Identity: profile tables keyed to Supabase Auth (docs/plans/2026-11-22-002 KTD1).
-- Supabase Auth owns providers and OTP; we keep only profile data.

-- Never hand new public tables to anon by default (KTD4). Each migration also revokes
-- explicitly, so this only protects against a future migration forgetting.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on functions from anon;

-- Non-exposed schema for internal helpers. No client role can use it.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Shared guard (KTD5): the owner of a row can never change. Not SECURITY DEFINER, so it
-- cannot escalate privileges; pinned search_path anyway. Works for any table: it only
-- checks the owner columns the row actually has. An upsert that leaves them unchanged passes.
create or replace function private.forbid_owner_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_col text;
begin
  foreach v_col in array array['id', 'user_id', 'created_by'] loop
    if to_jsonb(new) ? v_col
       and (to_jsonb(new) -> v_col) is distinct from (to_jsonb(old) -> v_col) then
      raise exception '% is immutable', v_col using errcode = '42501';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function private.forbid_owner_change() from public, anon, authenticated;

-- users: one row per auth user. Created by the Phase 3 sign-up trigger, never by clients.
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 64),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- user_profile: body stats and computed targets, 1-1 with users.
create table public.user_profile (
  id uuid primary key default auth.uid() references public.users (id) on delete cascade,
  height_cm numeric(5, 1) not null check (height_cm > 0 and height_cm < 300),
  birth_date date not null check (birth_date between date '1900-01-01' and date '2100-01-01'),
  gender text not null check (gender in ('male', 'female', 'other')),
  activity_level text not null
    check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  fitness_goal text not null check (fitness_goal in ('lose_fat', 'maintain', 'build_muscle')),
  target_weight_kg numeric(5, 2) check (target_weight_kg > 0 and target_weight_kg < 700),
  bmr_kcal numeric(7, 2) not null check (bmr_kcal >= 0 and bmr_kcal <= 10000),
  daily_calorie_target numeric(7, 2) not null
    check (daily_calorie_target >= 0 and daily_calorie_target <= 20000),
  protein_target_g numeric(6, 1) not null check (protein_target_g >= 0 and protein_target_g <= 2000),
  carb_target_g numeric(6, 1) not null check (carb_target_g >= 0 and carb_target_g <= 3000),
  fat_target_g numeric(6, 1) not null check (fat_target_g >= 0 and fat_target_g <= 2000),
  updated_at timestamptz not null default now()
);

create trigger users_forbid_owner_change
  before update on public.users
  for each row execute function private.forbid_owner_change();
create trigger user_profile_forbid_owner_change
  before update on public.user_profile
  for each row execute function private.forbid_owner_change();

-- RLS: enabled with the table, one policy per operation, scoped to the caller.
alter table public.users enable row level security;
alter table public.user_profile enable row level security;

-- Grants (KTD4): revoke everything, then grant only what each table allows.
revoke all on public.users from anon, authenticated;
revoke all on public.user_profile from anon, authenticated;
grant select, update on public.users to authenticated;       -- no insert/delete from clients
grant select, insert, update on public.user_profile to authenticated; -- removal is by cascade

create policy users_select on public.users
  for select to authenticated using (id = (select auth.uid()));
create policy users_update on public.users
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy user_profile_select on public.user_profile
  for select to authenticated using (id = (select auth.uid()));
create policy user_profile_insert on public.user_profile
  for insert to authenticated with check (id = (select auth.uid()));
create policy user_profile_update on public.user_profile
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
