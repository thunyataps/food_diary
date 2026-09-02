create table meal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  photo_url text,
  note text,
  eaten_at timestamptz not null default now(),
  total_calories numeric not null default 0,
  total_protein numeric not null default 0,
  total_carb numeric not null default 0,
  total_fat numeric not null default 0,
  created_at timestamptz not null default now()
);

create table food_items (
  id uuid primary key default gen_random_uuid(),
  meal_entry_id uuid not null references meal_entries(id) on delete cascade,
  name text not null,
  quantity text not null,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carb numeric not null default 0,
  fat numeric not null default 0,
  source text not null default 'ai' check (source in ('ai', 'user_edited'))
);

alter table meal_entries enable row level security;
alter table food_items enable row level security;

create policy "meal_entries_select_own" on meal_entries
  for select using (auth.uid() = user_id);
create policy "meal_entries_insert_own" on meal_entries
  for insert with check (auth.uid() = user_id);
create policy "meal_entries_update_own" on meal_entries
  for update using (auth.uid() = user_id);
create policy "meal_entries_delete_own" on meal_entries
  for delete using (auth.uid() = user_id);

create policy "food_items_select_own" on food_items
  for select using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_insert_own" on food_items
  for insert with check (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_update_own" on food_items
  for update using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );
create policy "food_items_delete_own" on food_items
  for delete using (
    exists (select 1 from meal_entries m where m.id = meal_entry_id and m.user_id = auth.uid())
  );

create index meal_entries_user_eaten_at_idx on meal_entries (user_id, eaten_at desc);
create index food_items_meal_entry_id_idx on food_items (meal_entry_id);
