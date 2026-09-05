-- ============================================================
-- EC8A Scanner | 0006_storage.sql
-- Private bucket for EC 8A photos: agents write only into their
-- own folder; every authenticated user can view (dashboard).
-- ============================================================

insert into storage.buckets (id, name, public)
values ('ec8a-photos', 'ec8a-photos', false)
on conflict (id) do nothing;

create policy "agents upload to own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'ec8a-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "authenticated read photos"
on storage.objects for select to authenticated
using (bucket_id = 'ec8a-photos');

create policy "admins manage photos"
on storage.objects for all to authenticated
using (bucket_id = 'ec8a-photos' and public.is_admin())
with check (bucket_id = 'ec8a-photos' and public.is_admin());

-- Realtime: dashboard listens to these tables and refetches the tally views.
alter publication supabase_realtime add table public.submissions;
alter publication supabase_realtime add table public.submission_votes;