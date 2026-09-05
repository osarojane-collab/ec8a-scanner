import '../../data/models.dart';

/// Builds the results CSV: one row per polling unit (its LATEST entry,
/// exactly what the live tally counts), one column per party, plus the
/// duplicate/conflict audit flags.
///
/// Column order: identity + audit columns, then parties with the home
/// party (NDC) first. Standard CSV escaping (quote fields containing
/// commas/quotes/newlines).

String csvEscape(Object? v) {
  final s = v?.toString() ?? '';
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String buildResultsCsv({
  required List<PuRollupRow> rows,
  required List<LatestVoteRow> votes,
  required List<Party> parties,
  String? homePartyAbbr,
}) {
  final cols = [...parties];
  if (homePartyAbbr != null) {
    final home = parties
        .where((p) => p.abbr.toUpperCase() == homePartyAbbr.toUpperCase())
        .toList();
    for (final h in home.reversed) {
      cols
        ..remove(h)
        ..insert(0, h);
    }
  }

  final votesBySub = <String, Map<String, int>>{};
  for (final v in votes) {
    votesBySub.putIfAbsent(v.submissionId, () => {})[v.partyId] = v.votes;
  }

  final buf = StringBuffer();
  buf.writeln(
    [
      'pu_code',
      'pu_name',
      'ward',
      'lga',
      'state',
      'entries',
      'duplicate_flag',
      'cross_checked',
      'conflict_flag',
      'total_votes_cast',
      'accredited_voters',
      'latest_at',
      ...cols.map((p) => p.abbr),
    ].map(csvEscape).join(','),
  );

  for (final r in rows) {
    final pv = votesBySub[r.latestSubmissionId] ?? const <String, int>{};
    buf.writeln(
      [
        r.puCode,
        r.puName,
        r.ward,
        r.lga,
        r.state,
        r.entriesCount,
        r.duplicateFlag,
        r.crossChecked,
        r.conflictFlag,
        r.sheetTotalVotesCast ?? '',
        r.accreditedVoters ?? '',
        r.latestAt?.toIso8601String() ?? '',
        ...cols.map((p) => pv[p.id] ?? ''),
      ].map(csvEscape).join(','),
    );
  }
  return buf.toString();
}
