import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';

/// Manage one team: assigned polling units + members.
class AdminTeamDetail extends ConsumerStatefulWidget {
  final Team team;
  const AdminTeamDetail({super.key, required this.team});

  @override
  ConsumerState<AdminTeamDetail> createState() => _AdminTeamDetailState();
}

class _AdminTeamDetailState extends ConsumerState<AdminTeamDetail> {
  late Future<List<PollingUnit>> _assigned;
  late Future<List<Map<String, dynamic>>> _members;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final admin = ref.read(adminRepoProvider);
    final catalog = ref.read(catalogRepoProvider);
    setState(() {
      _assigned = admin.assignedPuIdsForTeam(widget.team.id).then((ids) async {
        if (ids.isEmpty) return const <PollingUnit>[];
        final all = await catalog.pollingUnits();
        return all.where((p) => ids.contains(p.id)).toList();
      });
      _members = admin.teamMemberRows(widget.team.id);
    });
  }

  Future<void> _assignPu() async {
    final all = await ref.read(catalogRepoProvider).pollingUnits();
    final assignedIds = (await _assigned).map((p) => p.id).toSet();
    if (!mounted) return;
    final query = TextEditingController();
    final selected = await showDialog<PollingUnit>(
      context: context,
      builder: (ctx) => Dialog(
        child: StatefulBuilder(
          builder: (ctx, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: query,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Search polling units'),
                  onChanged: (_) => setD(() {}),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final pu in all)
                      if (!assignedIds.contains(pu.id) &&
                          (query.text.isEmpty ||
                              '${pu.code} ${pu.name} ${pu.ward} ${pu.lga}'
                                  .toLowerCase()
                                  .contains(query.text.toLowerCase())))
                        ListTile(
                          dense: true,
                          title: Text('${pu.code} — ${pu.name}'),
                          subtitle: Text('${pu.ward} / ${pu.lga}'),
                          onTap: () => Navigator.pop(ctx, pu),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await ref
          .read(adminRepoProvider)
          .assignUnit(widget.team.id, selected.id);
      _reload();
    }
  }

  Future<void> _addMember() async {
    final profiles = await ref.read(profilesProvider.future);
    final memberIds =
        (await _members).map((m) => m['user_id'] as String).toSet();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => Dialog(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Add member',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final p in profiles)
              if (!memberIds.contains(p['id']))
                ListTile(
                  dense: true,
                  title: Text((p['full_name'] ?? '') as String),
                  subtitle: Text((p['email'] ?? '') as String),
                  onTap: () => Navigator.pop(ctx, p),
                ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref
          .read(adminRepoProvider)
          .addMember(widget.team.id, selected['id'] as String);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('Assigned polling units',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Assign polling unit',
                icon: const Icon(Icons.add_location_alt_outlined),
                onPressed: _assignPu,
              ),
            ],
          ),
          FutureBuilder<List<PollingUnit>>(
            future: _assigned,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Text('None assigned yet.');
              }
              return Column(
                children: [
                  for (final pu in list)
                    ListTile(
                      dense: true,
                      title: Text('${pu.code} — ${pu.name}'),
                      subtitle: Text('${pu.ward} / ${pu.lga}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18),
                        onPressed: () async {
                          await ref
                              .read(adminRepoProvider)
                              .unassignUnit(widget.team.id, pu.id);
                          _reload();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Add member',
                icon: const Icon(Icons.person_add_alt_outlined),
                onPressed: _addMember,
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _members,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }
              final members = snap.data!;
              if (members.isEmpty) {
                return const Text('No members yet.');
              }
              return Column(
                children: [
                  for (final m in members)
                    ListTile(
                      dense: true,
                      title: Text(((m['profiles'] as Map<String, dynamic>?)
                                  ?['full_name'] ??
                              'unknown') as String),
                      subtitle: Text(
                          ((m['profiles'] as Map<String, dynamic>?)
                                      ?['email'] ??
                                  '') as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18),
                        onPressed: () async {
                          await ref
                              .read(adminRepoProvider)
                              .removeMember(
                                  widget.team.id, m['user_id'] as String);
                          _reload();
                        },
                      ),
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
