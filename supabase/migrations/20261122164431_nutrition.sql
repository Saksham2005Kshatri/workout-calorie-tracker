-- Nutrition: food reference data, meals and meal items (plan U4).
-- Meal totals are derived by a view and never stored (KTD7).

-- food_item: seeded/imported rows (created_by NULL, read-only to clients) plus a user's custom foods.
create table public.food_item (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 200),
  kcal_per_100g numeric(7, 2) not null check (kcal_per_100g >= 0 and kcal_per_100g <= 900),
  protein_per_100g numeric(5, 2) not null check (protein_per_100g >= 0 and protein_per_100g <= 100),
  carbs_per_100g numeric(5, 2) not null check (carbs_per_100g >= 0 and carbs_per_100g <= 100),
  fat_per_100g numeric(5, 2) not null check (fat_per_100g >= 0 and fat_per_100g <= 100),
  source text not null check (source in ('usda', 'open_food_facts', 'user')),
  created_by uuid default auth.uid() references public.users (id) on delete cascade,
  -- Macros cannot exceed the weight of the food.
  constraint food_item_macros_within_100g
    check (protein_per_100g + carbs_per_100g + fat_per_100g <= 100),
  -- A client can only create 'user' foods, and only server-imported rows may claim another source.
  constraint food_item_source_matches_owner check ((created_by is null) = (source <> 'user'))
);
create index food_item_created_by_idx on public.food_item (created_by);

create table public.meal (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  eaten_at timestamptz not null default now(),
  -- Storage path inside the owner's own folder (Phase 8 adds the bucket and its policies).
  photo_url text check (
    photo_url is null
    or (char_length(photo_url) <= 300 and photo_url like user_id::text || '/%')
  ),
  status text not null default 'draft' check (status in ('draft', 'confirmed')),
  constraint meal_id_user_key unique (id, user_id)
);
create index meal_user_eaten_idx on public.meal (user_id, eaten_at desc);

create table public.meal_item (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null,
  user_id uuid not null default auth.uid(),
  -- The item keeps its own copied nutrition values, so the link is dropped if the food is deleted.
  food_item_id uuid references public.food_item (id) on delete set null,
  ingredient_name text not null check (char_length(ingredient_name) between 1 and 200),
  portion_g numeric(8, 2) not null check (portion_g > 0 and portion_g <= 10000),
  calories numeric(8, 2) not null check (calories >= 0 and calories <= 20000),
  protein_g numeric(7, 2) not null check (protein_g >= 0 and protein_g <= 2000),
  carbs_g numeric(7, 2) not null check (carbs_g >= 0 and carbs_g <= 2000),
  fat_g numeric(7, 2) not null check (fat_g >= 0 and fat_g <= 2000),
  -- Client-asserted, not authoritative: the confirm step is a UX control (KTD13).
  source text not null check (source in ('ai', 'user')),
  user_confirmed boolean not null default false,
  constraint meal_item_meal_fk foreign key (meal_id, user_id)
    references public.meal (id, user_id) on delete cascade
);
create index meal_item_user_idx on public.meal_item (user_id);
create index meal_item_meal_idx on public.meal_item (meal_id);
create index meal_item_food_idx on public.meal_item (food_item_id);

create trigger food_item_forbid_owner_change before update on public.food_item
  for each row execute function private.forbid_owner_change();
create trigger meal_forbid_owner_change before update on public.meal
  for each row execute function private.forbid_owner_change();
create trigger meal_item_forbid_owner_change before update on public.meal_item
  for each row execute function private.forbid_owner_change();

alter table public.food_item enable row level security;
alter table public.meal enable row level security;
alter table public.meal_item enable row level security;

revoke all on public.food_item, public.meal, public.meal_item from anon, authenticated;
grant select, insert, update, delete on public.food_item, public.meal, public.meal_item to authenticated;

-- food_item: same shape as exercise (KTD6).
create policy food_item_select on public.food_item
  for select to authenticated using (created_by is null or created_by = (select auth.uid()));
create policy food_item_insert on public.food_item
  for insert to authenticated with check (created_by = (select auth.uid()));
create policy food_item_update on public.food_item
  for update to authenticated
  using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));
create policy food_item_delete on public.food_item
  for delete to authenticated using (created_by = (select auth.uid()));

create policy meal_select on public.meal
  for select to authenticated using (user_id = (select auth.uid()));
create policy meal_insert on public.meal
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy meal_update on public.meal
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy meal_delete on public.meal
  for delete to authenticated using (user_id = (select auth.uid()));

-- meal_item: a linked food must be visible to the caller (KTD12), as for session_exercise.
create policy meal_item_select on public.meal_item
  for select to authenticated using (user_id = (select auth.uid()));
create policy meal_item_insert on public.meal_item
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and (food_item_id is null or exists (select 1 from public.food_item f where f.id = food_item_id)));
create policy meal_item_update on public.meal_item
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (food_item_id is null or exists (select 1 from public.food_item f where f.id = food_item_id)));
create policy meal_item_delete on public.meal_item
  for delete to authenticated using (user_id = (select auth.uid()));

-- Derived meal totals (KTD7). security_invoker makes the view obey the caller's RLS on meal and
-- meal_item; the left join returns zeros for a meal with no items yet.
create view public.meal_totals with (security_invoker = true) as
select
  m.id as meal_id,
  m.user_id,
  coalesce(sum(i.calories), 0)::numeric(10, 2) as total_calories,
  coalesce(sum(i.protein_g), 0)::numeric(9, 2) as total_protein_g,
  coalesce(sum(i.carbs_g), 0)::numeric(9, 2) as total_carbs_g,
  coalesce(sum(i.fat_g), 0)::numeric(9, 2) as total_fat_g
from public.meal m
left join public.meal_item i on i.meal_id = m.id
group by m.id, m.user_id;

revoke all on public.meal_totals from anon, authenticated;
grant select on public.meal_totals to authenticated;
