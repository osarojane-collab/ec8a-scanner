import '../data/models.dart';
import '../data/submission.dart';
import 'app_user.dart';

/// A submission stored in demo mode (in memory).
class DemoSubmission {
  final String id;
  final String puId;
  final String teamId;
  final String submittedBy;
  final int? accreditedVoters;
  final int? totalVotesCast;
  final String source;
  final DateTime createdAt;
  final List<PartyVote> votes;
  const DemoSubmission({
    required this.id,
    required this.puId,
    required this.teamId,
    required this.submittedBy,
    required this.accreditedVoters,
    required this.totalVotesCast,
    required this.source,
    required this.createdAt,
    required this.votes,
  });
}

/// In-memory data store powering demo mode (no Supabase required).
/// Seeds 6 sample polling units, 2 teams, 5 parties and 3 recorded PUs so
/// every dashboard state is visible: Recorded, Cross-checked and Conflict.
class DemoStore {
  DemoStore._() {
    _seed();
  }
  static final DemoStore I = DemoStore._();

  static const AppUser user = AppUser(
    id: 'demo-user',
    email: 'demo@ndc.ng',
    fullName: 'Demo Agent',
  );

  int _seq = 0;
  String _nextId() => 'd-sub-${++_seq}';

  // NOTE: the outer lists are intentionally non-const so demo admin
  // operations (import PUs, add team, confirm party) can mutate them.
  final List<Party> parties = [
    Party(
        id: 'd-ndc',
        abbr: 'NDC',
        name: 'Nigeria Democratic Congress',
        color: '#046A38',
        status: 'confirmed'),
    Party(
        id: 'd-apc',
        abbr: 'APC',
        name: 'All Progressives Congress',
        color: '#4B5563',
        status: 'confirmed'),
    Party(
        id: 'd-pdp',
        abbr: 'PDP',
        name: 'Peoples Democratic Party',
        color: '#4B5563',
        status: 'confirmed'),
    Party(
        id: 'd-lp',
        abbr: 'LP',
        name: 'Labour Party',
        color: '#4B5563',
        status: 'confirmed'),
    Party(
        id: 'd-nnpp',
        abbr: 'NNPP',
        name: 'New Nigeria Peoples Party',
        color: '#4B5563',
        status: 'confirmed'),
  ];

  final Election election = const Election(
      id: 'd-election',
      name: '2027 General Election',
      electionType: 'general',
      isActive: true);

  String homePartyId = 'd-ndc';
  String activeElectionId = 'd-election';

  final List<Map<String, dynamic>> members = [
    {'team_id': 'd-team1', 'user_id': 'demo-user', 'is_lead': true},
    {'team_id': 'd-team2', 'user_id': 'demo-agent-2', 'is_lead': true},
  ];

  final List<Map<String, dynamic>> profiles = [
    {
      'id': 'demo-user',
      'full_name': 'Demo Agent',
      'email': 'demo@ndc.ng',
      'role': 'admin'
    },
    {
      'id': 'demo-agent-2',
      'full_name': 'Bola Agent',
      'email': 'bola@ndc.ng',
      'role': 'agent'
    },
    {
      'id': 'demo-agent-3',
      'full_name': 'Chidi Agent',
      'email': 'chidi@ndc.ng',
      'role': 'agent'
    },
    {
      'id': 'demo-agent-4',
      'full_name': 'Ngozi Agent',
      'email': 'ngozi@ndc.ng',
      'role': 'agent'
    },
  ];

  final List<PollingUnit> pus = [
    const PollingUnit(
        id: 'd-pu1',
        code: '25/06/01/001',
        name: 'Kabusa I - Open Space',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Kabusa'),
    const PollingUnit(
        id: 'd-pu2',
        code: '25/06/01/002',
        name: 'Kabusa II - Market Sq',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Kabusa'),
    const PollingUnit(
        id: 'd-pu3',
        code: '25/06/01/003',
        name: 'Kpanji - Primary School',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Kpanji'),
    const PollingUnit(
        id: 'd-pu4',
        code: '25/06/02/001',
        name: 'Gwarinpa I - Junction',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Gwarinpa'),
    const PollingUnit(
        id: 'd-pu5',
        code: '25/06/02/002',
        name: 'Gwarinpa II - School',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Gwarinpa'),
    const PollingUnit(
        id: 'd-pu6',
        code: '25/06/02/003',
        name: 'Gwarinpa III - Health Ctr',
        state: 'FCT',
        lga: 'Municipal',
        ward: 'Gwarinpa'),
  ];

  final List<Team> teams = [
    const Team(id: 'd-team1', name: 'Municipal Ward 1 Team'),
    const Team(id: 'd-team2', name: 'Municipal Ward 2 Team'),
  ];

  final List<String> myTeamIds = const ['d-team1'];

  final Map<String, String> teamIdsByPu = {
    'd-pu1': 'd-team1',
    'd-pu2': 'd-team1',
    'd-pu3': 'd-team1',
    'd-pu4': 'd-team2',
    'd-pu5': 'd-team2',
    'd-pu6': 'd-team2',
  };

  final List<DemoSubmission> submissions = [];

  void _seed() {
    // PU 1: single entry -> "Recorded"
    _add(
        puId: 'd-pu1',
        accred: 310,
        total: 291,
        votes: {'NDC': 152, 'APC': 87, 'PDP': 43, 'LP': 9, 'NNPP': 0},
        minutesAgo: 95,
        source: 'ocr');
    // PU 2: two AGREEING entries -> "Cross-checked"
    for (final minutes in [70, 40]) {
      _add(
          puId: 'd-pu2',
          accred: 240,
          total: 200,
          votes: {'NDC': 98, 'APC': 60, 'PDP': 30, 'LP': 12},
          minutesAgo: minutes,
          source: 'ocr');
    }
    // PU 3: two CONFLICTING entries -> "Conflict"
    _add(
        puId: 'd-pu3',
        accred: 180,
        total: 130,
        votes: {'NDC': 70, 'APC': 55, 'PDP': 5},
        minutesAgo: 55,
        source: 'manual');
    _add(
        puId: 'd-pu3',
        accred: 180,
        total: 135,
        votes: {'NDC': 75, 'APC': 55, 'PDP': 5},
        minutesAgo: 20,
        source: 'ocr');
  }

  void _add({
    required String puId,
    required int? accred,
    required int total,
    required Map<String, int> votes,
    required int minutesAgo,
    String source = 'manual',
  }) {
    submissions.add(DemoSubmission(
      id: _nextId(),
      puId: puId,
      teamId: teamIdsByPu[puId] ?? 'd-team1',
      submittedBy: user.id,
      accreditedVoters: accred,
      totalVotesCast: total,
      source: source,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      votes: [
        for (final e in votes.entries)
          PartyVote(
              abbr: e.key,
              name: parties.firstWhere((p) => p.abbr == e.key).name,
              votes: e.value,
              confidence: source == 'ocr' ? 1.0 : 0.5),
      ],
    ));
  }

  /// Adds a new submission from the submit flow (demo replaces the RPC).
  void addSubmission(SubmissionPayload p) {
    submissions.add(DemoSubmission(
      id: _nextId(),
      puId: p.pollingUnitId,
      teamId: p.teamId,
      submittedBy: user.id,
      accreditedVoters: p.accreditedVoters,
      totalVotesCast: p.sheetTotalVotesCast,
      source: p.source,
      createdAt: DateTime.now(),
      votes: List.of(p.votes),
    ));
  }
}
