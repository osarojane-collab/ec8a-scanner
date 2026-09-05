import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/admin_repository.dart';
import '../data/local/sync_queue.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/submission.dart';
import '../data/submission_repository.dart';
import 'app_user.dart';
import 'demo_admin.dart';
import 'demo_repos.dart';
import 'demo_state.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Repositories: demo implementations when running without Supabase
/// credentials, otherwise the real Supabase-backed ones.
final authRepoProvider = Provider<AuthRepository>((ref) =>
    AppConfig.demoMode
        ? DemoAuthRepository.I
        : AuthRepository(ref.watch(supabaseProvider)));

final catalogRepoProvider = Provider<CatalogRepository>((ref) =>
    AppConfig.demoMode
        ? DemoCatalogRepository()
        : CatalogRepository(ref.watch(supabaseProvider)));

final dashboardRepoProvider = Provider<DashboardRepository>((ref) =>
    AppConfig.demoMode
        ? DemoDashboardRepository()
        : DashboardRepository(ref.watch(supabaseProvider)));

final submissionRepoProvider = Provider<SubmissionRepository>((ref) =>
    AppConfig.demoMode
        ? DemoSubmissionRepository()
        : SubmissionRepository(ref.watch(supabaseProvider)));

final adminRepoProvider = Provider<AdminRepository>((ref) =>
    AppConfig.demoMode
        ? DemoAdminRepository()
        : AdminRepository(ref.watch(supabaseProvider)));

/// Emits the signed-in user immediately, then every auth change.
/// (App-level identity: real mode maps the Supabase session; demo mode
/// is the in-memory demo agent.)
final sessionProvider = StreamProvider<AppUser?>((ref) async* {
  if (AppConfig.demoMode) {
    yield* DemoAuthRepository.I.onUser;
    return;
  }
  final repo = ref.watch(authRepoProvider);
  final s = repo.currentSession;
  final u = s?.user;
  if (u != null) {
    yield AppUser(
      id: u.id,
      email: u.email ?? '',
      fullName: u.userMetadata?['full_name'] as String? ?? '',
    );
  }
  await for (final st in repo.onAuthStateChange) {
    final su = st.session?.user;
    yield su == null
        ? null
        : AppUser(
            id: su.id,
            email: su.email ?? '',
            fullName: su.userMetadata?['full_name'] as String? ?? '',
          );
  }
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;
  if (AppConfig.demoMode) {
    return {
      'id': session.id,
      'full_name': session.fullName,
      'email': session.email,
      'role': 'admin',
    };
  }
  return ref.watch(authRepoProvider).myProfile();
});

final homePartyProvider =
    FutureProvider<Party?>((ref) => ref.watch(catalogRepoProvider).homeParty());

final partiesProvider = FutureProvider<List<Party>>(
    (ref) => ref.watch(catalogRepoProvider).parties());

final activeElectionProvider = FutureProvider<Election?>(
    (ref) => ref.watch(catalogRepoProvider).activeElection());

final myTeamIdsProvider = FutureProvider<List<String>>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return const [];
  return ref.watch(catalogRepoProvider).myTeamIds();
});

final myAssignmentsProvider = FutureProvider<List<PollingUnit>>((ref) async {
  final teamIds = await ref.watch(myTeamIdsProvider.future);
  return ref.watch(catalogRepoProvider).assignedUnits(teamIds);
});

final puTeamNamesProvider = FutureProvider<Map<String, String>>(
    (ref) => ref.watch(catalogRepoProvider).teamNamesForPus());

/// The full Team objects for the signed-in user's memberships.
final myTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final ids = await ref.watch(myTeamIdsProvider.future);
  if (ids.isEmpty) return const [];
  final all = await ref.watch(catalogRepoProvider).teams();
  return all.where((t) => ids.contains(t.id)).toList();
});

final teamsAllProvider = FutureProvider<List<Team>>(
    (ref) => ref.watch(catalogRepoProvider).teams());

final profilesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(adminRepoProvider).profilesList());

/// Dashboard reads (latest-wins totals + duplicate/conflict flags).
final tallyProvider = FutureProvider<List<TallyRow>>(
    (ref) => ref.watch(dashboardRepoProvider).overallTally());

final puRollupProvider = FutureProvider<List<PuRollupRow>>(
    (ref) => ref.watch(dashboardRepoProvider).puRollup());

/// Live updates: any change to submissions or their votes invalidates the
/// dashboard providers, which refetch the rollup views (auto-updating totals).
/// (No-op in demo mode - the demo submit flow invalidates directly.)
final dashboardRealtimeProvider = Provider<void>((ref) {
  if (AppConfig.demoMode) return;
  final c = ref.watch(supabaseProvider);
  void onChange(PostgresChangePayload _) {
    ref.invalidate(tallyProvider);
    ref.invalidate(puRollupProvider);
  }

  final channel = c.channel('public:dashboard-changes');
  for (final ev in PostgresChangeEvent.values) {
    channel.onPostgresChanges(
      event: ev,
      schema: 'public',
      table: 'submissions',
      callback: onChange,
    );
    channel.onPostgresChanges(
      event: ev,
      schema: 'public',
      table: 'submission_votes',
      callback: onChange,
    );
  }
  channel.subscribe();
  ref.onDispose(() => c.removeChannel(channel));
});

// ---- offline-first submission flow ---------------------------------------

final syncQueueProvider = FutureProvider<SyncQueue>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return SyncQueue(
      File('${dir.path}${Platform.pathSeparator}pending_sync.json'));
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final queue = await ref.watch(syncQueueProvider.future);
  return SyncService(ref.watch(supabaseProvider), queue);
});

final pendingCountProvider = FutureProvider<int>((ref) async {
  if (AppConfig.demoMode) return 0;
  final queue = await ref.watch(syncQueueProvider.future);
  return (await queue.load()).length;
});

/// Demo submit flow: "syncs" into the in-memory store and refreshes the
/// dashboard providers, so the tally/badges visibly update.
/// (Defined here, not in demo_repos, to avoid a circular import.)
class DemoSubmissionFlow implements SubmissionFlow {
  @override
  final Ref ref;
  DemoSubmissionFlow(this.ref);

  @override
  Future<bool> submit(SubmissionPayload payload,
      {String? localPhotoPath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    DemoStore.I.addSubmission(payload);
    ref.invalidate(pendingCountProvider);
    ref.invalidate(puRollupProvider);
    ref.invalidate(tallyProvider);
    return true;
  }
}
class SubmissionFlow {
  final Ref ref;
  SubmissionFlow(this.ref);

  Future<bool> submit(SubmissionPayload payload,
      {String? localPhotoPath}) async {
    final queue = await ref.read(syncQueueProvider.future);
    await queue.enqueue(
      PendingItem(
        clientUid: payload.clientUid,
        payload: payload.toRpcJson(),
        photoPath: localPhotoPath,
      ),
    );
    final synced = await ref.read(syncServiceProvider.future).then((s) => s.flush());
    ref.invalidate(pendingCountProvider);
    ref.invalidate(puRollupProvider);
    ref.invalidate(tallyProvider);
    return synced > 0;
  }
}

final submissionFlowProvider = Provider<SubmissionFlow>((ref) =>
    AppConfig.demoMode ? DemoSubmissionFlow(ref) : SubmissionFlow(ref));
