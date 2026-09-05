-- ============================================================
-- EC8A Scanner | 0008_profiles_email.sql
-- Store each user's email on their profile so admins can pick
-- team members by email in the app.
-- ============================================================

alter table public.profiles add column if not exists email text;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'agent')
  )
  on conflict (id) do nothing;
  return new;
end; $$;

-- Backfill emails for users created before this migration.
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;