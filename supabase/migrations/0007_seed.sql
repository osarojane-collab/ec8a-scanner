-- ============================================================
-- EC8A Scanner | 0007_seed.sql
-- * Party reference catalog (NDC first). NOTE: the source of truth is the
--   EC 8A form itself - scans auto-add unknown abbreviations as 'pending'
--   for admin confirmation, so this list never needs to be complete.
-- * Active election + app_settings with NDC as the home party.
-- * Sample polling units + sample team (test data - replace via CSV import).
-- ============================================================

insert into public.parties (abbr, name, sort_order) values
  ('NDC',  'Nigeria Democratic Congress',        1),
  ('APC',  'All Progressives Congress',          2),
  ('PDP',  'Peoples Democratic Party',           3),
  ('LP',   'Labour Party',                       4),
  ('NNPP', 'New Nigeria Peoples Party',          5),
  ('ADC',  'African Democratic Congress',        6),
  ('APGA', 'All Progressives Grand Alliance',    7),
  ('SDP',  'Social Democratic Party',            8),
  ('YPP',  'Young Progressives Party',           9),
  ('AAC',  'African Action Congress',           10),
  ('ADP',  'Action Democratic Party',           11),
  ('APP',  'Action Peoples Party',              12),
  ('BP',   'Boot Party',                        13),
  ('NRM',  'National Rescue Movement',          14),
  ('PRP',  'People''s Redemption Party',       15),
  ('APM',  'Allied Peoples Movement',           16),
  ('A',    'Action Alliance',                   17),
  ('ZLP',  'Zenith Labour Party',               18)
on conflict (abbr) do update set name = excluded.name, sort_order = excluded.sort_order;

-- Any other party printed on a future form is auto-added as 'pending' by
-- the submit_ec8a RPC and confirmed by an admin - nothing is hard-coded.

insert into public.elections (name, election_type, election_date, is_active)
values ('2027 General Election', 'general', '2027-02-20', true)
on conflict do nothing;

insert into public.app_settings (id, active_election_id, home_party_id)
values (
  1,
  (select id from public.elections where is_active limit 1),
  (select id from public.parties where abbr = 'NDC')
)
on conflict (id) do update set
  active_election_id = excluded.active_election_id,
  home_party_id      = excluded.home_party_id,
  updated_at         = now();

-- ---- SAMPLE polling units & team (test data, replace via CSV import) ----
insert into public.polling_units (code, name, state, lga, ward) values
  ('25/06/01/001', 'Kabusa I     - Open Space',   'FCT', 'Municipal', 'Kabusa'),
  ('25/06/01/002', 'Kabusa II    - Market Sq',    'FCT', 'Municipal', 'Kabusa'),
  ('25/06/01/003', 'Kpanji       - Primary Sch',  'FCT', 'Municipal', 'Kpanji'),
  ('25/06/02/001', 'Gwarinpa I   - Junction',     'FCT', 'Municipal', 'Gwarinpa'),
  ('25/06/02/002', 'Gwarinpa II  - School',       'FCT', 'Municipal', 'Gwarinpa'),
  ('25/06/02/003', 'Gwarinpa III - Health Ctr',   'FCT', 'Municipal', 'Gwarinpa')
on conflict (code) do nothing;

insert into public.teams (name, state, lga, ward) values
  ('Municipal Ward 1 Team', 'FCT', 'Municipal', 'Kabusa'),
  ('Municipal Ward 2 Team', 'FCT', 'Municipal', 'Gwarinpa')
on conflict (name) do nothing;

insert into public.team_assignments (team_id, polling_unit_id)
select t.id, p.id
from public.teams t
join public.polling_units p on (
  (t.name = 'Municipal Ward 1 Team' and p.ward = 'Kabusa') or
  (t.name = 'Municipal Ward 2 Team' and p.ward = 'Gwarinpa')
)
on conflict do nothing;

-- NOTE: team members are added after users sign up (see README step 5):
--   insert into public.team_members (team_id, user_id)
--   select '<team-uuid>', '<auth-user-uuid>';