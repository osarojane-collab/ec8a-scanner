import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/submission.dart';
import '../../state/providers.dart';
import 'ec8a_parser.dart';
import 'vote_rows_editor.dart';

/// Final gate before a submission: photo side-by-side with the extracted
/// votes, manual corrections, sum-check against "total votes cast", then
/// submit (online, or queued for offline sync).
class ReviewScreen extends ConsumerStatefulWidget {
  final PollingUnit pollingUnit;
  final String? photoPath; // null = manual entry
  final Ec8aParseResult parse;
  final String? sourceOverride; // 'qr' when values came from the QR code
  const ReviewScreen({
    super.key,
    required this.pollingUnit,
    required this.parse,
    this.photoPath,
    this.sourceOverride,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final List<ParsedRow> _rows;
  late final Map<int, TextEditingController> _ctrls;
  late final TextEditingController _accredited;
  late final TextEditingController _total;
  late final TextEditingController _rejected;
  String? _teamId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rows = [...widget.parse.rows];
    _ctrls = {
      for (var i = 0; i < _rows.length; i++)
        i: TextEditingController(text: _rows[i].votes?.toString() ?? ''),
    };
    _accredited = TextEditingController(
        text: widget.parse.accreditedVoters?.toString() ?? '');
    _total = TextEditingController(
        text: widget.parse.totalVotesCast?.toString() ?? '');
    _rejected = TextEditingController(
        text: widget.parse.rejectedBallots?.toString() ?? '');
    Future.microtask(() async {
      final teams = await ref.read(myTeamsProvider.future);
      if (mounted && _teamId == null && teams.isNotEmpty) {
        setState(() => _teamId = teams.first.id);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _accredited.dispose();
    _total.dispose();
    _rejected.dispose();
    super.dispose();
  }

  int? get _sum {
    var hasAny = false;
    var sum = 0;
    for (var i = 0; i < _rows.length; i++) {
      final v = int.tryParse(_ctrls[i]!.text.trim());
      if (v == null) continue;
      hasAny = true;
      sum += v;
    }
    return hasAny ? sum : null;
  }

  int? get _totalCast => int.tryParse(_total.text.trim());

  Future<void> _addParty() async {
    final res = await AddPartyDialog().show(context);
    if (res == null) return;
    setState(() {
      _rows.add(ParsedRow(
          abbr: res.$1, fullName: res.$2, votes: res.$3, confidence: 0.5));
      _ctrls[_rows.length - 1] =
          TextEditingController(text: res.$3?.toString() ?? '');
    });
  }

  Future<void> _submit() async {
    final teamId = _teamId;
    if (teamId == null) {
      _snack('Select your team first.');
      return;
    }
    final votes = <PartyVote>[];
    for (var i = 0; i < _rows.length; i++) {
      final v = int.tryParse(_ctrls[i]!.text.trim());
      if (v == null) {
        _snack('Enter votes for ${_rows[i].abbr}.');
        return;
      }
      votes.add(PartyVote(
        abbr: _rows[i].abbr,
        name: _rows[i].fullName ?? _rows[i].abbr,
        votes: v,
        confidence: _rows[i].confidence,
      ));
    }
    if (votes.isEmpty) {
      _snack('Add at least one party row.');
      return;
    }

    final sum = votes.fold(0, (a, b) => a + b.votes);
    final total = int.tryParse(_total.text.trim());
    if (total != null && sum != total) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Votes do not add up'),
          content: Text(
            'Sum of party votes ($sum) does not equal the sheet total '
            'votes cast ($total).\n\nGo back and correct, or submit anyway?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Correct it')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final clientUid = const Uuid().v4();
    final uid = ref.read(sessionProvider).value?.id;
    final election = ref.read(activeElectionProvider).value;
    final confidences =
        votes.map((v) => v.confidence).whereType<double>().toList();
    final payload = SubmissionPayload(
      clientUid: clientUid,
      electionId: election?.id,
      pollingUnitId: widget.pollingUnit.id,
      teamId: teamId,
      photoPath: uid == null || widget.photoPath == null
          ? null
          : '$uid/$clientUid.jpg',
      accreditedVoters: int.tryParse(_accredited.text.trim()),
      sheetTotalVotesCast: total,
      rejectedBallots: int.tryParse(_rejected.text.trim()),
      source: widget.sourceOverride ??
          (widget.photoPath == null ? 'manual' : 'ocr'),
      ocrConfidence: confidences.isEmpty
          ? null
          : confidences.fold(0.0, (a, b) => a + b) / confidences.length,
      votes: votes,
    );

    setState(() => _submitting = true);
    try {
      final ok = await ref
          .read(submissionFlowProvider)
          .submit(payload, localPhotoPath: widget.photoPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Submitted. Thank you!'
              : 'Saved offline - it will sync automatically.'),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Submit failed: $e');
      }
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final pu = widget.pollingUnit;
    final teams = ref.watch(myTeamsProvider);
    final sum = _sum;
    final totalCast = _totalCast;
    final mismatch = sum != null && totalCast != null && sum != totalCast;

    return Scaffold(
      appBar: AppBar(title: Text('Review — ${pu.code}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.photoPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(widget.photoPath!),
                  height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
          ],
          if (mismatch)
            Material(
              color: Colors.deepOrange.shade100,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(
                  'Party votes sum to $sum, sheet says $totalCast. '
                  'Please verify against the photo.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Polling unit',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('${pu.code} — ${pu.name}\n${pu.locationLabel}'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _numField(_accredited, 'Accredited'),
                  const SizedBox(width: 8),
                  _numField(_total, 'Total cast'),
                  const SizedBox(width: 8),
                  _numField(_rejected, 'Rejected'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Party votes',
                          style: Theme.of(context).textTheme.titleSmall),
                      TextButton.icon(
                        onPressed: _addParty,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  VoteRowsEditor(
                    rows: _rows,
                    controllers: _ctrls,
                    onRemove: (i) => setState(() {
                      _ctrls.remove(i)?.dispose();
                      _rows.removeAt(i);
                      final pairs = <int, TextEditingController>{};
                      for (var k = 0; k < _rows.length; k++) {
                        pairs[k] = _ctrls[k + (k >= i ? 1 : 0)]!;
                      }
                      _ctrls
                        ..clear()
                        ..addAll(pairs);
                    }),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: teams.when(
                loading: () => const Text('Loading teams...'),
                error: (e, _) => Text('Teams error: $e'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Text(
                        'You are not in any team yet - ask your coordinator.');
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _teamId,
                    decoration:
                        const InputDecoration(labelText: 'Submitting as team'),
                    items: [
                      for (final t in list)
                        DropdownMenuItem(value: t.id, child: Text(t.name)),
                    ],
                    onChanged: (v) => setState(() => _teamId = v),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit results'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );
}
