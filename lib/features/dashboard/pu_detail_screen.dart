import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/submission.dart';
import '../../state/providers.dart';
import '../home/pu_badge.dart';

/// Per-PU detail: every EC 8A entry for the polling unit, newest first,
/// with per-party votes, source and photo. Duplicates/conflicts visible.
class PuDetailScreen extends ConsumerStatefulWidget {
  final PuRollupRow rollup;
  const PuDetailScreen({super.key, required this.rollup});

  @override
  ConsumerState<PuDetailScreen> createState() => _PuDetailScreenState();
}

class _PuDetailScreenState extends ConsumerState<PuDetailScreen> {
  late Future<List<SubmissionEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries =
        ref.read(submissionRepoProvider).entriesForPu(widget.rollup.puId);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rollup;
    return Scaffold(
      appBar: AppBar(title: Text('${r.puCode} — entries')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(r.puName),
              subtitle: Text('${r.ward} / ${r.lga} / ${r.state}'),
              trailing: PuBadge(roll: r),
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<SubmissionEntry>>(
            future: _entries,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snap.hasError) {
                return Text('Failed to load entries: ${snap.error}');
              }
              final entries = snap.data ?? const <SubmissionEntry>[];
              if (entries.isEmpty) {
                return const Text('No entries yet.');
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _EntryCard(
                      entry: entries[i],
                      isLatest: i == 0,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  final SubmissionEntry entry;
  final bool isLatest;
  const _EntryCard({required this.entry, required this.isLatest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = entry.createdAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLatest)
                  const Chip(
                    label: Text('LATEST — counted in tally',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Colors.teal,
                  )
                else
                  const Chip(
                    label: Text('history — not counted',
                        style: TextStyle(fontSize: 11)),
                  ),
                const Spacer(),
                Text(
                  '${created.month}/${created.day} '
                  '${created.hour.toString().padLeft(2, '0')}:'
                  '${created.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Text('source: ${entry.source} • status: ${entry.status}'),
            if (entry.sheetTotalVotesCast != null)
              Text('Total votes cast: ${entry.sheetTotalVotesCast}'),
            if (entry.accreditedVoters != null)
              Text('Accredited voters: ${entry.accreditedVoters}'),
            const Divider(),
            ...entry.votes.map(
              (v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${v.abbr} — ${v.name}')),
                    Text(v.votes.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
            if (entry.photoPath != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final url = await ref
                        .read(submissionRepoProvider)
                        .photoUrl(entry.photoPath!);
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog.fullscreen(
                          child: InteractiveViewer(
                            child: Center(child: Image.network(url)),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('View photo'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
