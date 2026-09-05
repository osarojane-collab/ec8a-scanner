import '../data/admin_repository.dart';
import '../data/models.dart';
import 'demo_state.dart';

/// Demo admin: all operations mutate the in-memory store so the whole
/// admin experience (CSV import, teams, assignments, members, party
/// confirmation) can be exercised without a backend.
class DemoAdminRepository implements AdminRepository {
  final _store = DemoStore.I;

  @override
  Future<void> importPollingUnits(List<List<dynamic>> rows) async {
    for (final r in rows) {
      if (r.length < 5) continue;
      final state = r[0].toString().trim();
      if (state.isEmpty || state.toLowerCase() == 'state') continue;
      final code = r[3].toString().trim();
      if (code.isEmpty) continue;
      final pu = PollingUnit(
        id: 'd-pu-${code.replaceAll('/', '-')}',
        code: code,
        name: r[4].toString().trim(),
        state: state,
        lga: r[1].toString().trim(),
        ward: r[2].toString().trim(),
      );
      final i = _store.pus.indexWhere((p) => p.code == code);
      if (i >= 0) {
        _store.pus[i] = pu;
      } else {
        _store.pus.add(pu);
      }
    }
  }

  @override
  Future<void> addTeam(String name, String? state, String? lga, String? ward) async {
    _store.teams.add(Team(id: 'd-team-${_store.teams.length + 1}', name: name));
  }

  @override
  Future<void> assignUnit(String teamId, String puId) async =>
      _store.teamIdsByPu[puId] = teamId;

  @override
  Future<void> unassignUnit(String teamId, String puId) async {
    if (_store.teamIdsByPu[puId] == teamId) _store.teamIdsByPu.remove(puId);
  }

  @override
  Future<void> addMember(String teamId, String userId, {bool lead = false}) async =>
      _store.members.add({'team_id': teamId, 'user_id': userId, 'is_lead': lead});

  @override
  Future<void> removeMember(String teamId, String userId) async =>
      _store.members.removeWhere(
          (m) => m['team_id'] == teamId && m['user_id'] == userId);

  @override
  Future<void> confirmParty(String partyId) async {
    final i = _store.parties.indexWhere((p) => p.id == partyId);
    if (i >= 0) {
      final p = _store.parties[i];
      _store.parties[i] =
          Party(id: p.id, abbr: p.abbr, name: p.name, color: p.color, status: 'confirmed');
    }
  }

  @override
  Future<void> updatePartyName(String partyId, String name) async {
    final i = _store.parties.indexWhere((p) => p.id == partyId);
    if (i >= 0) {
      final p = _store.parties[i];
      _store.parties[i] =
          Party(id: p.id, abbr: p.abbr, name: name, color: p.color, status: p.status);
    }
  }

  @override
  Future<void> setHomeParty(String partyId) async =>
      _store.homePartyId = partyId;

  @override
  Future<void> setActiveElection(String electionId) async =>
      _store.activeElectionId = electionId;

  @override
  Future<List<Map<String, dynamic>>> teamMemberRows(String teamId) async => [
        for (final m in _store.members)
          if (m['team_id'] == teamId)
            {
              'user_id': m['user_id'],
              'is_lead': m['is_lead'],
              'profiles': _store.profiles
                  .firstWhere((p) => p['id'] == m['user_id']),
            },
      ];

  @override
  Future<List<Map<String, dynamic>>> profilesList() async =>
      List.of(_store.profiles);

  @override
  Future<List<String>> assignedPuIdsForTeam(String teamId) async => [
        for (final e in _store.teamIdsByPu.entries)
          if (e.value == teamId) e.key,
      ];
}