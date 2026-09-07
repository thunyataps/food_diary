create table weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  logged_date date not null,
  weight_kg numeric not null,
  created_at timestamptz not null default now(),
  unique (user_id, logged_date)
);

alter table weight_logs enable row level security;

create policy "weight_logs_select_own" on weight_logs
  for select using (auth.uid() = user_id);
create policy "weight_logs_insert_own" on weight_logs
  for insert with check (auth.uid() = user_id);
create policy "weight_logs_update_own" on weight_logs
  for update using (auth.uid() = user_id);
create policy "weight_logs_delete_own" on weight_logs
  for delete using (auth.uid() = user_id);

create index weight_logs_user_date_idx on weight_logs (user_id, logged_date desc);
