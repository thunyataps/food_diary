create table user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age integer,
  height_cm numeric,
  body_fat_pct numeric,
  muscle_mass_kg numeric,
  updated_at timestamptz not null default now()
);

alter table user_profiles enable row level security;

create policy "user_profiles_select_own" on user_profiles
  for select using (auth.uid() = user_id);
create policy "user_profiles_insert_own" on user_profiles
  for insert with check (auth.uid() = user_id);
create policy "user_profiles_update_own" on user_profiles
  for update using (auth.uid() = user_id);
create policy "user_profiles_delete_own" on user_profiles
  for delete using (auth.uid() = user_id);
