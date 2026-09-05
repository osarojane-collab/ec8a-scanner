import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../state/providers.dart';
import '../export/results_csv.dart';

/// Admin export: builds a CSV of the latest entry per polling unit (the
/// same numbers the live tally uses), one column per party (NDC first),
/// plus the duplicate/conflict audit flags. Saves to the app documents
/// folder and offers clipboard copy for pasting into Sheets/WhatsApp.
class ExportTab extends ConsumerStatefulWidget {
  const ExportTab({super.key});

  @override
  ConsumerState<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends ConsumerState<ExportTab> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final rollup = await ref.read(dashboardRepoProvider).puRollup();
      final votes = await ref.read(dashboardRepoProvider).latestVotes();
      final parties = await ref.read(catalogRepoProvider).parties();
      final home = await ref.read(catalogRepoProvider).homeParty();

      final csv = buildResultsCsv(
        rows: rollup,
        votes: votes,
        parties: parties,
        homePartyAbbr: home?.abbr,
      );

      final dir = await getApplicationDocumentsDirectory();
      final f = File(
          '${dir.path}${Platform.pathSeparator}ec8a_results_${DateTime.now().millisecondsSinceEpoch}.csv');
      await f.writeAsString(csv, flush: true);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('CSV ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${rollup.length} polling unit(s), ${parties.length} parties'),
              const SizedBox(height: 12),
              const Text('Saved to:'),
              SelectableText(f.path, style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy to clipboard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ios_share, size: 48),
            const SizedBox(height: 12),
            Text('Export results',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Generates a CSV with the latest entry for every polling unit '
              '(the same numbers as the live tally), one column per party '
              'with NDC first, plus duplicate/conflict flags for audit.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_view),
              label: const Text('Generate results CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
