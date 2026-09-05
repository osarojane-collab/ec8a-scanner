-- ============================================================
-- EC8A Scanner | 0009_pu_latest_votes.sql
-- The per-party votes of the LATEST submission for every polling
-- unit (same numbers the overall tally uses) - powers CSV export.
-- ============================================================

create or replace view public.pu_latest_votes
with (security_invoker = true) as
select
  r.pu_id,
  r.latest_submission_id,
  v.party_id,
  p.abbr,
  p.name,
  v.votes
from public.pu_rollup r
join public.submission_votes v on v.submission_id = r.latest_submission_id
join public.parties p on p.id = v.party_id;