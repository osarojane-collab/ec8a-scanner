import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../scan/capture_screen.dart';
import 'pu_badge.dart';

/// "My polling units": the PUs assigned to the user's team(s). Tapping a PU
/// opens the capture flow. Shows duplicate/conflict badges from the rollup
/// view and the offline sync queue status.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(myAssignmentsProvider);
    final teamNames = ref.watch(puTeamNamesProvider);
    final rollup = ref.watch(puRollupProvider);
    final pending = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Polling Units'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(myAssignmentsProvider);
              ref.invalidate(puTeamNamesProvider);
              ref.invalidate(puRollupProvider);
              ref.invalidate(pendingCountProvider);
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepoProvider).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pending.valueOrNull case final count? when count > 0)
            Material(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text('$count submission(s) waiting to sync'),
                trailing: TextButton(
                  onPressed: () async {
                    final sync = await ref.read(syncServiceProvider.future);
                    final n = await sync.flush();
                    ref.invalidate(pendingCountProvider);
                    ref.invalidate(puRollupProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Synced $n submission(s)')),
                      );
                    }
                  },
                  child: const Text('Sync now'),
                ),
              ),
            ),
          Expanded(
            child: assignments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (units) {
                if (units.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No polling units assigned to your team yet.\n\n'
                        'Ask your coordinator (Admin tab -> Teams) to assign '
                        'polling units to your team.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final rollupByPu = {
                  for (final r in rollup.valueOrNull ?? const <PuRollupRow>[])
                    r.puId: r
                };
                final teamByPu = teamNames.valueOrNull ?? const {};
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myAssignmentsProvider);
                    ref.invalidate(puRollupProvider);
                  },
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, i) {
                      final pu = units[i];
                      final roll = rollupByPu[pu.id];
                      final hasEntries = (roll?.entriesCount ?? 0) > 0;
                      return Card(
                        child: ListTile(
                          title: Text('${pu.code} — ${pu.name}'),
                          subtitle: Text(
                            '${pu.locationLabel}'
                            '${teamByPu[pu.id] == null ? '' : '\nTeam: ${teamByPu[pu.id]}'}',
                          ),
                          isThreeLine: teamByPu[pu.id] != null,
                          trailing: PuBadge(roll: roll),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CaptureScreen(
                                pollingUnit: pu,
                                alreadyRecorded: hasEntries,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
