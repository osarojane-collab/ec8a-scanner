import '../data/models.dart';
import '../data/submission.dart';
import 'demo_state.dart';

/// Query extensions on [DemoStore] that mirror the SQL views:
///  * rollup()  ~ `pu_rollup`      (latest entry per PU + duplicate flags)
///  * tally()   ~ `overall_tally`  (every PU contributes its latest entry)
///  * entriesFor() ~ submission history for one PU, newest first
extension DemoStoreQueries on DemoStore {
  List<PuRollupRow> rollup() {
    final out = <PuRollupRow>[];
    for (final pu in pus) {
      final es = submissions.where((s) => s.puId == pu.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (es.isEmpty) continue;
      final latest = es.first;
      var conflict = false;
      final abbrs = es.expand((s) => s.votes.map((v) => v.abbr)).toSet();
      for (final abbr in abbrs) {
        final vals = <int>{};
        for (final s in es) {
          for (final v in s.votes) {
            if (v.abbr == abbr) vals.add(v.votes);
          }
        }
        if (vals.length > 1) conflict = true;
      }
      out.add(PuRollupRow(
        puId: pu.id,
        puCode: pu.code,
        puName: pu.name,
        state: pu.state,
        lga: pu.lga,
        ward: pu.ward,
        latestSubmissionId: latest.id,
        latestTeamId: latest.teamId,
        latestAt: latest.createdAt,
        sheetTotalVotesCast: latest.totalVotesCast,
        accreditedVoters: latest.accreditedVoters,
        entriesCount: es.length,
        duplicateFlag: es.length > 1,
        crossChecked: es.length > 1 && !conflict,
        conflictFlag: conflict,
      ));
    }
    out.sort((a, b) => a.puCode.compareTo(b.puCode));
    return out;
  }

  List<TallyRow> tally() {
    final roll = rollup();
    final totals = <String, int>{};
    final puCounts = <String, int>{};
    for (final r in roll) {
      final latest =
          submissions.firstWhere((s) => s.id == r.latestSubmissionId);
      for (final v in latest.votes) {
        totals[v.abbr] = (totals[v.abbr] ?? 0) + v.votes;
        puCounts[v.abbr] = (puCounts[v.abbr] ?? 0) + 1;
      }
    }
    final rows = <TallyRow>[];
    for (final p in parties) {
      rows.add(TallyRow(
        partyId: p.id,
        abbr: p.abbr,
        name: p.name,
        color: p.color,
        votes: totals[p.abbr] ?? 0,
        puCount: puCounts[p.abbr] ?? 0,
      ));
    }
    return rows;
  }

  List<SubmissionEntry> entriesFor(String puId) {
    final es = submissions.where((s) => s.puId == puId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final s in es)
        SubmissionEntry(
          id: s.id,
          pollingUnitId: s.puId,
          teamId: s.teamId,
          submittedBy: s.submittedBy,
          photoPath: null,
          accreditedVoters: s.accreditedVoters,
          sheetTotalVotesCast: s.totalVotesCast,
          rejectedBallots: null,
          source: s.source,
          status: 'submitted',
          createdAt: s.createdAt,
          votes: List.of(s.votes),
        ),
    ];
  }
}
