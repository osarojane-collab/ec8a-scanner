import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Auth + profile.
class AuthRepository {
  final SupabaseClient _c;
  AuthRepository(this._c);

  Session? get currentSession => _c.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _c.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _c.auth.signOut();

  /// Returns {id, full_name, phone, role} or null.
  Future<Map<String, dynamic>?> myProfile() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    return _c.from('profiles').select().eq('id', uid).maybeSingle();
  }
}

/// Reference data: settings, parties, polling units, teams, assignments.
class CatalogRepository {
  final SupabaseClient _c;
  CatalogRepository(this._c);

  Future<Party?> homeParty() async {
    final s =
        await _c.from('app_settings').select('home_party_id').maybeSingle();
    final pid = s?['home_party_id'] as String?;
    if (pid == null) return null;
    final p = await _c.from('parties').select().eq('id', pid).maybeSingle();
    return p == null ? null : Party.fromJson(p);
  }

  Future<Election?> activeElection() async {
    final s = await _c
        .from('app_settings')
        .select('active_election_id')
        .maybeSingle();
    final eid = s?['active_election_id'] as String?;
    if (eid == null) return null;
    final e = await _c.from('elections').select().eq('id', eid).maybeSingle();
    return e == null ? null : Election.fromJson(e);
  }

  Future<List<Party>> parties() async {
    final rows = await _c.from('parties').select().order('sort_order');
    return rows.map(Party.fromJson).toList();
  }

  Future<List<PollingUnit>> pollingUnits() async {
    final rows = await _c.from('polling_units').select().order('code');
    return rows.map(PollingUnit.fromJson).toList();
  }

  Future<List<Team>> teams() async {
    final rows = await _c.from('teams').select().order('name');
    return rows.map(Team.fromJson).toList();
  }

  /// Team ids the signed-in user belongs to.
  Future<List<String>> myTeamIds() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows =
        await _c.from('team_members').select('team_id').eq('user_id', uid);
    return rows.map((r) => r['team_id'] as String).toList();
  }

  /// Polling units assigned to any of [teamIds].
  Future<List<PollingUnit>> assignedUnits(List<String> teamIds) async {
    if (teamIds.isEmpty) return const [];
    final rows = await _c
        .from('team_assignments')
        .select('polling_unit_id')
        .inFilter('team_id', teamIds);
    final ids = rows.map((r) => r['polling_unit_id'] as String).toSet().toList();
    if (ids.isEmpty) return const [];
    final pus =
        await _c.from('polling_units').select().inFilter('id', ids).order('code');
    return pus.map(PollingUnit.fromJson).toList();
  }

  /// polling_unit_id -> team name (for "covered by" labels).
  Future<Map<String, String>> teamNamesForPus() async {
    final rows = await _c
        .from('team_assignments')
        .select('polling_unit_id, teams(name)');
    return {
      for (final r in rows)
        r['polling_unit_id'] as String:
            ((r['teams'] as Map<String, dynamic>?)?['name'] ?? '') as String,
    };
  }
}

/// Dashboard reads: overall tally + per-PU rollup (latest-wins, flags).
class DashboardRepository {
  final SupabaseClient _c;
  DashboardRepository(this._c);

  Future<List<TallyRow>> overallTally() async {
    final rows = await _c.from('overall_tally').select();
    final list = rows.map(TallyRow.fromJson).toList();
    list.sort((a, b) => a.abbr.compareTo(b.abbr));
    return list;
  }

  Future<List<PuRollupRow>> puRollup() async {
    final rows = await _c.from('pu_rollup').select().order('pu_code');
    return rows.map(PuRollupRow.fromJson).toList();
  }

  /// Per-party votes of the latest submission of every PU (CSV export).
  Future<List<LatestVoteRow>> latestVotes() async {
    final rows = await _c.from('pu_latest_votes').select();
    return rows.map(LatestVoteRow.fromJson).toList();
  }
}
