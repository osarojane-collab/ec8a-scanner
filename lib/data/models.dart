/// Reference-data models (DTOs mirroring the Supabase schema and views).
library;

class Party {
  final String id;
  final String abbr;
  final String name;
  final String color;
  final String status; // confirmed | pending
  const Party({
    required this.id,
    required this.abbr,
    required this.name,
    required this.color,
    required this.status,
  });

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        abbr: (j['abbr'] ?? '') as String,
        name: (j['name'] ?? j['abbr'] ?? '') as String,
        color: (j['color'] ?? '#4B5563') as String,
        status: (j['status'] ?? 'confirmed') as String,
      );
}

class Election {
  final String id;
  final String name;
  final String electionType;
  final bool isActive;
  const Election({
    required this.id,
    required this.name,
    required this.electionType,
    required this.isActive,
  });

  factory Election.fromJson(Map<String, dynamic> j) => Election(
        id: j['id'] as String,
        name: j['name'] as String,
        electionType: (j['election_type'] ?? 'general') as String,
        isActive: (j['is_active'] ?? false) as bool,
      );
}

class PollingUnit {
  final String id;
  final String code;
  final String name;
  final String state;
  final String lga;
  final String ward;
  const PollingUnit({
    required this.id,
    required this.code,
    required this.name,
    required this.state,
    required this.lga,
    required this.ward,
  });

  factory PollingUnit.fromJson(Map<String, dynamic> j) => PollingUnit(
        id: j['id'] as String,
        code: j['code'] as String,
        name: (j['name'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        lga: (j['lga'] ?? '') as String,
        ward: (j['ward'] ?? '') as String,
      );

  String get locationLabel => '$ward / $lga / $state';
}

class Team {
  final String id;
  final String name;
  const Team({required this.id, required this.name});

  factory Team.fromJson(Map<String, dynamic> j) =>
      Team(id: j['id'] as String, name: j['name'] as String);
}

/// One row of the `pu_rollup` view: latest entry per PU + duplicate flags.
class PuRollupRow {
  final String puId;
  final String puCode;
  final String puName;
  final String state;
  final String lga;
  final String ward;
  final String latestSubmissionId;
  final String latestTeamId;
  final DateTime? latestAt;
  final int? sheetTotalVotesCast;
  final int? accreditedVoters;
  final int entriesCount;
  final bool duplicateFlag;
  final bool crossChecked;
  final bool conflictFlag;
  const PuRollupRow({
    required this.puId,
    required this.puCode,
    required this.puName,
    required this.state,
    required this.lga,
    required this.ward,
    required this.latestSubmissionId,
    required this.latestTeamId,
    required this.latestAt,
    required this.sheetTotalVotesCast,
    required this.accreditedVoters,
    required this.entriesCount,
    required this.duplicateFlag,
    required this.crossChecked,
    required this.conflictFlag,
  });

  factory PuRollupRow.fromJson(Map<String, dynamic> j) => PuRollupRow(
        puId: j['pu_id'] as String,
        puCode: (j['pu_code'] ?? '') as String,
        puName: (j['pu_name'] ?? '') as String,
        state: (j['state'] ?? '') as String,
        lga: (j['lga'] ?? '') as String,
        ward: (j['ward'] ?? '') as String,
        latestSubmissionId: j['latest_submission_id'] as String,
        latestTeamId: (j['latest_team_id'] ?? '') as String,
        latestAt: j['latest_at'] == null
            ? null
            : DateTime.parse(j['latest_at'] as String),
        sheetTotalVotesCast: j['sheet_total_votes_cast'] as int?,
        accreditedVoters: j['accredited_voters'] as int?,
        entriesCount: (j['entries_count'] ?? 1) as int,
        duplicateFlag: (j['duplicate_flag'] ?? false) as bool,
        crossChecked: (j['cross_checked'] ?? false) as bool,
        conflictFlag: (j['conflict_flag'] ?? false) as bool,
      );
}

/// One row of the `overall_tally` view: total extracted votes per party.
class TallyRow {
  final String partyId;
  final String abbr;
  final String name;
  final String color;
  final int votes;
  final int puCount;
  const TallyRow({
    required this.partyId,
    required this.abbr,
    required this.name,
    required this.color,
    required this.votes,
    required this.puCount,
  });

  factory TallyRow.fromJson(Map<String, dynamic> j) => TallyRow(
        partyId: j['party_id'] as String,
        abbr: (j['abbr'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        color: (j['color'] ?? '#4B5563') as String,
        votes: (j['votes'] ?? 0) as int,
        puCount: (j['pu_count'] ?? 0) as int,
      );
}

/// One row of the `pu_latest_votes` view: the votes of the LATEST
/// submission for a polling unit (same numbers the tally uses).
class LatestVoteRow {
  final String puId;
  final String submissionId;
  final String partyId;
  final String abbr;
  final String name;
  final int votes;
  const LatestVoteRow({
    required this.puId,
    required this.submissionId,
    required this.partyId,
    required this.abbr,
    required this.name,
    required this.votes,
  });

  factory LatestVoteRow.fromJson(Map<String, dynamic> j) => LatestVoteRow(
        puId: j['pu_id'] as String,
        submissionId: j['latest_submission_id'] as String,
        partyId: j['party_id'] as String,
        abbr: (j['abbr'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        votes: (j['votes'] ?? 0) as int,
      );
}
