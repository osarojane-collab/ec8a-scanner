-- ============================================================
-- EC8A Scanner | 0003_views.sql
-- Rollup views implementing the agreed duplicate rules:
--   * Overall totals use the LATEST submission per polling unit only.
--   * Older entries are kept as immutable history and flagged.
--   * Duplicates that AGREE  -> cross_checked (green badge)
--   * Duplicates that DIFFER -> conflict_flag  (amber badge)
-- ============================================================

create or replace view public.pu_rollup
with (security_invoker = true) as
with ranked as (
  select
    s.*,
    row_number() over (partition by s.polling_unit_id
                       order by s.created_at desc, s.id desc) as rn,
    count(*)     over (partition by s.polling_unit_id)          as entries_count
  from public.submissions s
),
latest as (select * from ranked where rn = 1),
conflicts as (
  -- A PU conflicts when the same party has DIFFERENT values across its entries.
  select s.polling_unit_id
  from public.submissions s
  join public.submission_votes v on v.submission_id = s.id
  group by s.polling_unit_id, v.party_id
  having count(distinct s.id) > 1 and count(distinct v.votes) > 1
)
select
  l.polling_unit_id               as pu_id,
  pu.code                         as pu_code,
  pu.name                         as pu_name,
  pu.state, pu.lga, pu.ward,
  l.id                            as latest_submission_id,
  l.team_id                       as latest_team_id,
  l.submitted_by                  as latest_submitted_by,
  l.created_at                    as latest_at,
  l.sheet_total_votes_cast,
  l.accredited_voters,
  l.status                        as latest_status,
  l.entries_count,
  (l.entries_count > 1)           as duplicate_flag,
  (l.entries_count > 1 and not exists (
      select 1 from conflicts c where c.polling_unit_id = l.polling_unit_id
  ))                              as cross_checked,
  exists (
      select 1 from conflicts c where c.polling_unit_id = l.polling_unit_id
  )                               as conflict_flag
from latest l
join public.polling_units pu on pu.id = l.polling_unit_id;

-- Live overall tally: one row per party; every PU contributes exactly once
-- (its latest submission). Powers the auto-updating dashboard.
create or replace view public.overall_tally
with (security_invoker = true) as
with latest as (
  select distinct on (polling_unit_id) id, polling_unit_id
  from public.submissions
  order by polling_unit_id, created_at desc, id desc
)
select
  v.party_id,
  p.abbr,
  p.name,
  p.color,
  p.status           as party_status,
  sum(v.votes)::bigint as votes,
  count(*)::bigint     as pu_count
from latest l
join public.submission_votes v on v.submission_id = l.id
join public.parties p          on p.id = v.party_id
group by v.party_id, p.abbr, p.name, p.color, p.status;