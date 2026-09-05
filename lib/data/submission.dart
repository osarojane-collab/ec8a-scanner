/// Votes for one party inside a submission.
class PartyVote {
  final String abbr;
  final String name;
  final int votes;
  final double? confidence;
  const PartyVote({
    required this.abbr,
    required this.name,
    required this.votes,
    this.confidence,
  });

  Map<String, dynamic> toRpcJson() => {
        'abbr': abbr,
        'name': name,
        'votes': votes,
        if (confidence != null) 'confidence': confidence,
      };
}

/// The full device-side payload handed to the `submit_ec8a` RPC.
class SubmissionPayload {
  final String clientUid;
  final String? electionId;
  final String pollingUnitId;
  final String teamId;
  final String? photoPath;
  final int? accreditedVoters;
  final int? sheetTotalVotesCast;
  final int? rejectedBallots;
  final String source;
  final double? ocrConfidence;
  final Map<String, dynamic>? ocrRaw;
  final List<PartyVote> votes;
  const SubmissionPayload({
    required this.clientUid,
    required this.pollingUnitId,
    required this.teamId,
    required this.votes,
    this.electionId,
    this.photoPath,
    this.accreditedVoters,
    this.sheetTotalVotesCast,
    this.rejectedBallots,
    this.source = 'ocr',
    this.ocrConfidence,
    this.ocrRaw,
  });

  Map<String, dynamic> toRpcJson() => {
        'client_uid': clientUid,
        if (electionId != null) 'election_id': electionId,
        'polling_unit_id': pollingUnitId,
        'team_id': teamId,
        if (photoPath != null) 'photo_path': photoPath,
        if (accreditedVoters != null) 'accredited_voters': accreditedVoters,
        if (sheetTotalVotesCast != null)
          'sheet_total_votes_cast': sheetTotalVotesCast,
        if (rejectedBallots != null) 'rejected_ballots': rejectedBallots,
        'source': source,
        if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
        if (ocrRaw != null) 'ocr_raw': ocrRaw,
        'votes': votes.map((v) => v.toRpcJson()).toList(),
      };
}

/// One EC 8A entry from the `submissions` table (PU detail / history view).
class SubmissionEntry {
  final String id;
  final String pollingUnitId;
  final String teamId;
  final String submittedBy;
  final String? photoPath;
  final int? accreditedVoters;
  final int? sheetTotalVotesCast;
  final int? rejectedBallots;
  final String source;
  final String status;
  final DateTime createdAt;
  final List<PartyVote> votes;
  const SubmissionEntry({
    required this.id,
    required this.pollingUnitId,
    required this.teamId,
    required this.submittedBy,
    required this.photoPath,
    required this.accreditedVoters,
    required this.sheetTotalVotesCast,
    required this.rejectedBallots,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.votes,
  });

  factory SubmissionEntry.fromJson(
    Map<String, dynamic> j,
    List<PartyVote> votes,
  ) =>
      SubmissionEntry(
        id: j['id'] as String,
        pollingUnitId: j['polling_unit_id'] as String,
        teamId: (j['team_id'] ?? '') as String,
        submittedBy: (j['submitted_by'] ?? '') as String,
        photoPath: j['photo_path'] as String?,
        accreditedVoters: j['accredited_voters'] as int?,
        sheetTotalVotesCast: j['sheet_total_votes_cast'] as int?,
        rejectedBallots: j['rejected_ballots'] as int?,
        source: (j['source'] ?? 'ocr') as String,
        status: (j['status'] ?? 'submitted') as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        votes: votes,
      );
}
