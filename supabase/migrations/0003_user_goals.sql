create table user_goals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_calories numeric not null,
  daily_protein numeric not null,
  daily_carb numeric not null,
  daily_fat numeric not null,
  updated_at timestamptz not null default now()
);

alter table user_goals enable row level security;

create policy "user_goals_select_own" on user_goals
  for select using (auth.uid() = user_id);
create policy "user_goals_insert_own" on user_goals
  for insert with check (auth.uid() = user_id);
create policy "user_goals_update_own" on user_goals
  for update using (auth.uid() = user_id);
create policy "user_goals_delete_own" on user_goals
  for delete using (auth.uid() = user_id);
