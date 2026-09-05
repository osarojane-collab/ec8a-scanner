import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'admin_export_tab.dart';
import 'admin_team_detail.dart';

/// Admin tab: import polling units (CSV), manage parties, manage teams.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Polling units'),
              Tab(icon: Icon(Icons.flag), text: 'Parties'),
              Tab(icon: Icon(Icons.groups), text: 'Teams'),
              Tab(icon: Icon(Icons.ios_share), text: 'Export'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UnitsTab(), _PartiesTab(), _TeamsTab(), ExportTab()],
        ),
      ),
    );
  }
}

class _UnitsTab extends ConsumerStatefulWidget {
  const _UnitsTab();

  @override
  ConsumerState<_UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends ConsumerState<_UnitsTab> {
  Future<int>? _count;

  @override
  void initState() {
    super.initState();
    _count = _loadCount();
  }

  Future<int> _loadCount() async =>
      (await ref.read(catalogRepoProvider).pollingUnits()).length;

  Future<void> _importCsv() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (files.isEmpty || files.first.path == null) return;
    try {
      final text = await File(files.first.path!).readAsString();
      final rows =
          const CsvToListConverter(shouldParseNumbers: false).convert(text);
      await ref.read(adminRepoProvider).importPollingUnits(rows);
      if (!mounted) return;
      setState(() => _count = _loadCount());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported ${rows.length} CSV row(s)'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FilledButton.icon(
                onPressed: _importCsv,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import polling units (CSV)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'CSV columns: state, lga, ward, code, name\n'
                'A header row is skipped automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<int>(
            future: _count,
            builder: (context, snap) => Center(
              child: Text(
                snap.hasData
                    ? '${snap.data} polling units in database'
                    : 'Counting...',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PartiesTab extends ConsumerWidget {
  const _PartiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parties = ref.watch(partiesProvider);
    return parties.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load parties: $e')),
      data: (list) => ListView(
        children: [
          for (final p in list)
            ListTile(
              title: Text('${p.abbr} — ${p.name}'),
              subtitle: Text(p.status == 'pending'
                  ? 'Discovered from a scanned form - needs confirmation'
                  : 'Confirmed'),
              trailing: p.status == 'pending'
                  ? FilledButton.tonal(
                      onPressed: () async {
                        await ref.read(adminRepoProvider).confirmParty(p.id);
                        ref.invalidate(partiesProvider);
                      },
                      child: const Text('Confirm'),
                    )
                  : IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final ctrl = TextEditingController(text: p.name);
                        final newName = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Rename ${p.abbr}'),
                            content: TextField(controller: ctrl),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, ctrl.text.trim()),
                                  child: const Text('Save')),
                            ],
                          ),
                        );
                        if (newName != null && newName.isNotEmpty) {
                          await ref
                              .read(adminRepoProvider)
                              .updatePartyName(p.id, newName);
                          ref.invalidate(partiesProvider);
                        }
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

class _TeamsTab extends ConsumerWidget {
  const _TeamsTab();

  Future<void> _addTeam(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final lga = TextEditingController();
    final ward = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Team name')),
            TextField(
                controller: lga,
                decoration:
                    const InputDecoration(labelText: 'LGA (optional)')),
            TextField(
                controller: ward,
                decoration:
                    const InputDecoration(labelText: 'Ward (optional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(adminRepoProvider).addTeam(
            name.text.trim(),
            null,
            lga.text.trim(),
            ward.text.trim(),
          );
      ref.invalidate(teamsAllProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsAllProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTeam(context, ref),
        child: const Icon(Icons.add),
      ),
      body: teams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load teams: $e')),
        data: (list) => ListView(
          children: [
            for (final t in list)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(t.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => AdminTeamDetail(team: t)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}