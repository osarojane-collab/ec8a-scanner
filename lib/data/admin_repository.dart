import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin operations. All writes are guarded server-side by RLS
/// (admin-only policies) - this repository just talks to Supabase.
class AdminRepository {
  final SupabaseClient _c;
  AdminRepository(this._c);

  /// CSV rows expected as: state,lga,ward,code,name[,registered_voters].
  /// A header row (starting with "state") is skipped automatically.
  Future<void> importPollingUnits(List<List<dynamic>> rows) async {
    final pus = <Map<String, dynamic>>[];
    for (final r in rows) {
      if (r.length < 5) continue;
      final state = r[0].toString().trim();
      if (state.isEmpty || state.toLowerCase() == 'state') continue;
      final code = r[3].toString().trim();
      if (code.isEmpty) continue;
      pus.add({
        'state': state,
        'lga': r[1].toString().trim(),
        'ward': r[2].toString().trim(),
        'code': code,
        'name': r[4].toString().trim(),
        if (r.length > 5 && int.tryParse(r[5].toString().trim()) != null)
          'registered_voters': int.parse(r[5].toString().trim()),
      });
    }
    if (pus.isEmpty) return;
    await _c.from('polling_units').upsert(pus, onConflict: 'code');
  }

  Future<void> addTeam(String name, String? state, String? lga, String? ward) =>
      _c.from('teams').insert({
        'name': name,
        if (state != null && state.isNotEmpty) 'state': state,
        if (lga != null && lga.isNotEmpty) 'lga': lga,
        if (ward != null && ward.isNotEmpty) 'ward': ward,
      });

  Future<void> assignUnit(String teamId, String puId) =>
      _c.from('team_assignments').upsert(
        {'team_id': teamId, 'polling_unit_id': puId},
        onConflict: 'team_id,polling_unit_id',
      );

  Future<void> unassignUnit(String teamId, String puId) => _c
      .from('team_assignments')
      .delete()
      .eq('team_id', teamId)
      .eq('polling_unit_id', puId);

  Future<void> addMember(String teamId, String userId, {bool lead = false}) =>
      _c.from('team_members').upsert(
        {'team_id': teamId, 'user_id': userId, 'is_lead': lead},
        onConflict: 'team_id,user_id',
      );

  Future<void> removeMember(String teamId, String userId) => _c
      .from('team_members')
      .delete()
      .eq('team_id', teamId)
      .eq('user_id', userId);

  Future<void> confirmParty(String partyId) =>
      _c.from('parties').update({'status': 'confirmed'}).eq('id', partyId);

  Future<void> updatePartyName(String partyId, String name) =>
      _c.from('parties').update({'name': name}).eq('id', partyId);

  Future<void> setHomeParty(String partyId) => _c.from('app_settings').update({
        'home_party_id': partyId,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', 1);

  /// Team members (with profile names/emails) for the admin UI.
  Future<List<Map<String, dynamic>>> teamMemberRows(String teamId) async {
    final rows = await _c
        .from('team_members')
        .select('user_id, is_lead, profiles(full_name, email)')
        .eq('team_id', teamId);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// All profiles (admin-only by RLS).
  Future<List<Map<String, dynamic>>> profilesList() async {
    final rows = await _c
        .from('profiles')
        .select('id, full_name, email, role')
        .order('full_name');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// PUs currently assigned to one team.
  Future<List<String>> assignedPuIdsForTeam(String teamId) async {
    final rows = await _c
        .from('team_assignments')
        .select('polling_unit_id')
        .eq('team_id', teamId);
    return rows.map((r) => r['polling_unit_id'] as String).toList();
  }

  Future<void> setActiveElection(String electionId) =>
      _c.from('app_settings').update({
        'active_election_id': electionId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);
}
