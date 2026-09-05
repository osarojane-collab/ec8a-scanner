-- ============================================================
-- EC8A Scanner | 0004_rls.sql
-- Row Level Security + helper functions + signup trigger + the
-- submit_ec8a RPC (atomic, validated, idempotent submission).
-- ============================================================

alter table public.profiles         enable row level security;
alter table public.elections        enable row level security;
alter table public.parties          enable row level security;
alter table public.app_settings     enable row level security;
alter table public.polling_units    enable row level security;
alter table public.teams            enable row level security;
alter table public.team_members     enable row level security;
alter table public.team_assignments enable row level security;
alter table public.submissions      enable row level security;
alter table public.submission_votes enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_team_member(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.team_members m where m.team_id = t and m.user_id = auth.uid()
  );
$$;

-- profiles -----------------------------------------------------
create policy "profiles read own or admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());
create policy "profiles insert own"
  on public.profiles for insert with check (id = auth.uid());
create policy "profiles update own or admin"
  on public.profiles for update
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- shared reference data: every authenticated user reads; admins write ----
create policy "elections read"  on public.elections       for select using (auth.role() = 'authenticated');
create policy "elections admin" on public.elections       for all    using (public.is_admin()) with check (public.is_admin());
create policy "parties read"    on public.parties         for select using (auth.role() = 'authenticated');
create policy "parties admin"   on public.parties         for all    using (public.is_admin()) with check (public.is_admin());
create policy "settings read"   on public.app_settings    for select using (auth.role() = 'authenticated');
create policy "settings admin"  on public.app_settings    for all    using (public.is_admin()) with check (public.is_admin());
create policy "pus read"        on public.polling_units   for select using (auth.role() = 'authenticated');
create policy "pus admin"       on public.polling_units   for all    using (public.is_admin()) with check (public.is_admin());
create policy "teams read"      on public.teams           for select using (auth.role() = 'authenticated');
create policy "teams admin"     on public.teams           for all    using (public.is_admin()) with check (public.is_admin());
create policy "members read"    on public.team_members    for select using (auth.role() = 'authenticated');
create policy "members admin"   on public.team_members    for all    using (public.is_admin()) with check (public.is_admin());
create policy "assign read"     on public.team_assignments for select using (auth.role() = 'authenticated');
create policy "assign admin"    on public.team_assignments for all    using (public.is_admin()) with check (public.is_admin());

-- submissions: agents read all (internal tool), insert only for their own
-- team via the validated RPC; admins may verify/flag.
create policy "submissions read"  on public.submissions for select using (auth.role() = 'authenticated');
create policy "submissions insert" on public.submissions for insert with check (
  submitted_by = auth.uid() and public.is_team_member(team_id)
);
create policy "submissions admin update" on public.submissions for update
  using (public.is_admin()) with check (public.is_admin());

create policy "votes read"       on public.submission_votes for select using (auth.role() = 'authenticated');
create policy "votes admin write" on public.submission_votes for all
  using (public.is_admin()) with check (public.is_admin());

-- auto-create profile on signup (role/name can come from invite metadata) --
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'agent')
  )
  on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();