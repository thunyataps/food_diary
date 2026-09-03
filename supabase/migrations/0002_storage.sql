-- Private bucket holding meal photos, one folder per user: `<user_id>/<timestamp>.jpg`
-- (see DiaryRepository.saveMealEntry).
insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

-- Users may only read/write objects under their own `user_id/` prefix.
drop policy if exists "meal_photos_owner_rw" on storage.objects;
create policy "meal_photos_owner_rw" on storage.objects
  for all using (
    bucket_id = 'meal-photos' and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'meal-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
