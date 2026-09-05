-- ============================================================
-- EC8A Scanner | 0002_submissions.sql
-- One submission = one scanned/manual EC 8A entry for a polling unit.
-- ============================================================

create table public.submissions (
  id                     uuid primary key default gen_random_uuid(),
  client_uid             text unique,          -- device-generated id -> safe offline retries
  election_id            uuid references public.elections(id) on delete set null,
  polling_unit_id        uuid not null references public.polling_units(id) on delete restrict,
  team_id                uuid not null references public.teams(id)    on delete restrict,
  submitted_by           uuid not null references public.profiles(id) on delete restrict,
  photo_path             text,                 -- ec8a-photos/<auth_uid>/<client_uid>.jpg
  accredited_voters      int,
  sheet_total_votes_cast int,
  rejected_ballots       int,
  source                 text not null default 'ocr' check (source in ('ocr','qr','manual')),
  ocr_confidence         numeric(4,3),         -- 0..1 overall OCR confidence
  ocr_raw                jsonb,                -- raw ML Kit output for audit
  status                 text not null default 'submitted'
                           check (status in ('submitted','verified','flagged')),
  created_at             timestamptz not null default now()
);

create index submissions_pu_time_idx on public.submissions (polling_unit_id, created_at desc);
create index submissions_status_idx  on public.submissions (status);
create index submissions_team_idx    on public.submissions (team_id);

create table public.submission_votes (
  submission_id uuid not null references public.submissions(id) on delete cascade,
  party_id      uuid not null references public.parties(id)     on delete restrict,
  votes         int  not null check (votes >= 0),
  confidence    numeric(4,3),
  primary key (submission_id, party_id)
);

create index submission_votes_party_idx on public.submission_votes (party_id);