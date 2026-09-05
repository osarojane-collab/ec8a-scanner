import 'package:flutter/material.dart';

import 'ec8a_parser.dart';

/// Editable list of per-party vote rows extracted from the EC 8A photo.
/// Rows with low OCR confidence are tinted orange so the agent checks them
/// against the photo before submitting.
class VoteRowsEditor extends StatelessWidget {
  final List<ParsedRow> rows;
  final Map<int, TextEditingController> controllers;
  final ValueChanged<int>? onRemove;
  const VoteRowsEditor({
    super.key,
    required this.rows,
    required this.controllers,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Row(
            children: [
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove row',
                  onPressed: () => onRemove!(i),
                ),
              Expanded(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${rows[i].abbr}  ${rows[i].fullName ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: rows[i].confidence < 1
                      ? const Text(
                          'low OCR confidence - check the photo',
                          style:
                              TextStyle(fontSize: 11, color: Colors.deepOrange),
                        )
                      : null,
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    filled: rows[i].confidence < 1,
                    fillColor: Colors.deepOrange.withValues(alpha: 0.08),
                    hintText: 'votes',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Small dialog to manually add a party row the OCR missed.
class AddPartyDialog extends StatelessWidget {
  const AddPartyDialog({super.key});

  Future<(String, String, int?)?> show(BuildContext context) =>
      showDialog<(String, String, int?)>(
        context: context,
        builder: (_) => this,
      );

  @override
  Widget build(BuildContext context) {
    final abbr = TextEditingController();
    final name = TextEditingController();
    final votes = TextEditingController();
    return AlertDialog(
      title: const Text('Add party row'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: abbr,
            decoration:
                const InputDecoration(labelText: 'Abbreviation (e.g. APC)'),
          ),
          TextField(
            controller: name,
            decoration:
                const InputDecoration(labelText: 'Full name (optional)'),
          ),
          TextField(
            controller: votes,
            decoration: const InputDecoration(labelText: 'Votes'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final a = abbr.text.trim().toUpperCase();
            if (a.isEmpty) return;
            Navigator.pop(
              context,
              (a, name.text.trim(), int.tryParse(votes.text.trim())),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
