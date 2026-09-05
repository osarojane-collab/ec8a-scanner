import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../home/pu_badge.dart';
import 'pu_detail_screen.dart';

/// Live results dashboard: overall extracted votes per party (NDC
/// highlighted) plus the per-PU list with duplicate/conflict badges.
/// Auto-updates: dashboardRealtimeProvider subscribes to submission changes
/// and invalidates the providers, refetching the rollup views.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate the realtime subscription for this tab.
    ref.watch(dashboardRealtimeProvider);

    final tally = ref.watch(tallyProvider);
    final rollup = ref.watch(puRollupProvider);
    final homeParty = ref.watch(homePartyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall Tally'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(tallyProvider);
              ref.invalidate(puRollupProvider);
            },
          ),
        ],
      ),
      body: tally.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tally: $e')),
        data: (rows) {
          final home = homeParty.valueOrNull;
          final pus = rollup.valueOrNull ?? const <PuRollupRow>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (home != null)
                for (final r in rows.where((r) => r.partyId == home.id))
                  _TotalCard(row: r, highlighted: true),
              ...rows
                  .where((r) => home == null || r.partyId != home.id)
                  .map((r) => _TotalCard(row: r, highlighted: false)),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Polling units (${pus.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...pus.map((pu) => Card(
                    child: ListTile(
                      title: Text('${pu.puCode} — ${pu.puName}'),
                      subtitle: Text(
                        '${pu.ward} / ${pu.lga}'
                        ' • ${pu.entriesCount} entr${pu.entriesCount == 1 ? 'y' : 'ies'}'
                        ' • latest ${_fmt(pu.latestAt)}',
                      ),
                      trailing: PuBadge(roll: pu),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PuDetailScreen(rollup: pu),
                        ),
                      ),
                    ),
                  )),
              if (pus.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No submissions yet.'),
                ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TotalCard extends StatelessWidget {
  final TallyRow row;
  final bool highlighted;
  const _TotalCard({required this.row, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.abbr} — ${row.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${row.puCount} polling unit(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              row.votes.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}