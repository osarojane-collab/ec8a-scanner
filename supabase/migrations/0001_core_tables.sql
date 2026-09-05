-- ============================================================
-- EC8A Scanner | 0001_core_tables.sql
-- Core reference tables: profiles, elections, parties, settings,
-- polling units, NDC area teams and their PU assignments.
-- Run in the Supabase SQL editor in file-name order.
-- ============================================================

create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null,
  phone      text,
  role       text not null default 'agent' check (role in ('admin','agent')),
  created_at timestamptz not null default now()
);

create table public.elections (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  election_type text not null default 'general',  -- general | governorship | rerun | bye
  election_date date,
  is_active     boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Reference catalog of political parties. NOT hand-managed as the source
-- of truth: the EC 8A form prints the party list, so scans auto-upsert
-- unknown abbreviations here with status 'pending' (see 0004 RPCs).
create table public.parties (
  id          uuid primary key default gen_random_uuid(),
  abbr        text not null unique,
  name        text not null,
  color       text default '#4B5563',
  sort_order  int  not null default 100,
  status      text not null default 'confirmed' check (status in ('confirmed','pending')),
  created_at  timestamptz not null default now()
);

-- Single-row settings table.
create table public.app_settings (
  id                 int primary key default 1 check (id = 1),
  active_election_id uuid references public.elections(id) on delete set null,
  home_party_id      uuid references public.parties(id)  on delete set null,
  updated_at         timestamptz not null default now()
);

create table public.polling_units (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,   -- INEC PU code, e.g. 25/06/01/001
  name              text not null,
  state             text not null,
  lga               text not null,
  ward              text not null,
  registered_voters int,
  created_at        timestamptz not null default now()
);
create index polling_units_geo_idx on public.polling_units (state, lga, ward);

-- NDC area teams (party x area grouping).
create table public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  state      text,
  lga        text,
  ward       text,
  created_at timestamptz not null default now()
);

create table public.team_members (
  team_id uuid not null references public.teams(id)    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  is_lead boolean not null default false,
  primary key (team_id, user_id)
);

-- Which polling units each team is responsible for.
create table public.team_assignments (
  id              uuid primary key default gen_random_uuid(),
  team_id         uuid not null references public.teams(id) on delete cascade,
  polling_unit_id uuid not null references public.polling_units(id) on delete cascade,
  created_at      timestamptz not null default now(),
  unique (team_id, polling_unit_id)
);
create index team_assignments_pu_idx on public.team_assignments (polling_unit_id);