import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, Session;

import '../data/models.dart';
import '../data/repositories.dart';
import '../data/submission.dart';
import '../data/submission_repository.dart';
import 'app_user.dart';
import 'demo_rollup.dart';
import 'demo_state.dart';

/// Demo auth: auto-signed-in demo agent; sign-out returns to the login
/// screen where any credentials sign back in.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository._();
  static final DemoAuthRepository I = DemoAuthRepository._();

  final _ctrl = StreamController<AppUser?>.broadcast();

  /// Demo branch of [sessionProvider] listens here.
  Stream<AppUser?> get onUser async* {
    yield DemoStore.user;
    yield* _ctrl.stream;
  }

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _ctrl.add(DemoStore.user);
  }

  @override
  Future<void> signOut() => _ctrl.addStream(Stream.value(null));

  @override
  Future<Map<String, dynamic>?> myProfile() async =>
      DemoStore.I.profiles.first;
}

class DemoCatalogRepository implements CatalogRepository {
  final _store = DemoStore.I;

  @override
  Future<Party?> homeParty() async =>
      _store.parties.firstWhere((p) => p.id == _store.homePartyId);

  @override
  Future<Election?> activeElection() async => _store.election;

  @override
  Future<List<Party>> parties() async => List.of(_store.parties);

  @override
  Future<List<PollingUnit>> pollingUnits() async => List.of(_store.pus);

  @override
  Future<List<Team>> teams() async => List.of(_store.teams);

  @override
  Future<List<String>> myTeamIds() async => List.of(_store.myTeamIds);

  @override
  Future<List<PollingUnit>> assignedUnits(List<String> teamIds) async =>
      _store.pus
          .where((pu) => teamIds.contains(_store.teamIdsByPu[pu.id]))
          .toList();

  @override
  Future<Map<String, String>> teamNamesForPus() async {
    final nameById = {for (final t in _store.teams) t.id: t.name};
    return {
      for (final e in _store.teamIdsByPu.entries)
        e.key: nameById[e.value] ?? '',
    };
  }
}

class DemoDashboardRepository implements DashboardRepository {
  final _store = DemoStore.I;

  @override
  Future<List<TallyRow>> overallTally() async {
    final list = _store.tally();
    list.sort((a, b) => a.abbr.compareTo(b.abbr));
    return list;
  }

  @override
  Future<List<PuRollupRow>> puRollup() async => _store.rollup();

  @override
  Future<List<LatestVoteRow>> latestVotes() async {
    final rows = <LatestVoteRow>[];
    for (final r in _store.rollup()) {
      final latest = _store.submissions
          .firstWhere((s) => s.id == r.latestSubmissionId);
      for (final v in latest.votes) {
        final party = _store.parties.firstWhere(
          (p) => p.abbr == v.abbr,
          orElse: () => Party(
              id: 'pending-${v.abbr}',
              abbr: v.abbr,
              name: v.name,
              color: '#999999',
              status: 'pending'),
        );
        rows.add(LatestVoteRow(
          puId: r.puId,
          submissionId: r.latestSubmissionId,
          partyId: party.id,
          abbr: v.abbr,
          name: party.name,
          votes: v.votes,
        ));
      }
    }
    return rows;
  }
}

class DemoSubmissionRepository implements SubmissionRepository {
  final _store = DemoStore.I;

  @override
  Future<String> uploadPhoto(String localPath, String objectName) async =>
      objectName;

  @override
  Future<String> submit(SubmissionPayload payload) async {
    _store.addSubmission(payload);
    return 'ok';
  }

  @override
  Future<List<SubmissionEntry>> entriesForPu(String puId) async =>
      _store.entriesFor(puId);

  @override
  Future<String> photoUrl(String objectPath) async => '';
}