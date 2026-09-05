-- ============================================================
-- EC8A Scanner | 0005_rpc.sql
-- The one write path the app uses for submissions.
--   * validates the caller belongs to the team
--   * validates the PU is assigned to that team
--   * upserts parties unknown to the catalog (status = 'pending')
--   * inserts submission + per-party votes atomically
--   * idempotent on client_uid (offline retries are safe)
-- ============================================================

create or replace function public.upsert_party(p_abbr text, p_name text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  select id into v_id from public.parties where upper(abbr) = upper(p_abbr);
  if v_id is null then
    insert into public.parties (abbr, name, status, sort_order)
    values (p_abbr, coalesce(nullif(trim(p_name), ''), p_abbr), 'pending', 200)
    returning id into v_id;
  end if;
  return v_id;
end; $$;

create or replace function public.submit_ec8a(p_payload jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_submission uuid;
  v_pu         uuid;
  v_team       uuid;
  v_party      jsonb;
  v_party_id   uuid;
  v_client     text;
begin
  v_pu     := (p_payload->>'polling_unit_id')::uuid;
  v_team   := (p_payload->>'team_id')::uuid;
  v_client := p_payload->>'client_uid';

  if not public.is_team_member(v_team) then
    raise exception 'you are not a member of this team';
  end if;

  if not exists (
    select 1 from public.team_assignments a
    where a.team_id = v_team and a.polling_unit_id = v_pu
  ) then
    raise exception 'polling unit % is not assigned to this team', v_pu;
  end if;

  -- offline retry safety: same client_uid returns the original submission
  if v_client is not null then
    select id into v_submission from public.submissions where client_uid = v_client;
    if v_submission is not null then
      return v_submission;
    end if;
  end if;

  insert into public.submissions (
    id, client_uid, election_id, polling_unit_id, team_id, submitted_by,
    photo_path, accredited_voters, sheet_total_votes_cast, rejected_ballots,
    source, ocr_confidence, ocr_raw, status
  ) values (
    gen_random_uuid(), v_client,
    (p_payload->>'election_id')::uuid,
    v_pu, v_team, auth.uid(),
    p_payload->>'photo_path',
    (p_payload->>'accredited_voters')::int,
    (p_payload->>'sheet_total_votes_cast')::int,
    (p_payload->>'rejected_ballots')::int,
    coalesce(p_payload->>'source', 'ocr'),
    (p_payload->>'ocr_confidence')::numeric,
    p_payload->'ocr_raw',
    'submitted'
  )
  returning id into v_submission;

  for v_party in select * from jsonb_array_elements(p_payload->'votes')
  loop
    v_party_id := public.upsert_party(v_party->>'abbr', v_party->>'name');
    insert into public.submission_votes (submission_id, party_id, votes, confidence)
    values (v_submission, v_party_id,
            (v_party->>'votes')::int,
            (v_party->>'confidence')::numeric)
    on conflict (submission_id, party_id) do update
      set votes = excluded.votes, confidence = excluded.confidence;
  end loop;

  return v_submission;
end; $$;

grant execute on function public.submit_ec8a(jsonb) to authenticated;
grant execute on function public.upsert_party(text, text) to authenticated;