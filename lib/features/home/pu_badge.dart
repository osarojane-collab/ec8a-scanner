import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Status badge for a polling unit based on the `pu_rollup` view:
///  * no entries      -> chevron
///  * recorded once   -> Recorded
///  * duplicates that agree -> Cross-checked (green)
///  * duplicates that differ -> Conflict (orange)
///  * duplicates, undecided  -> N entries (grey)
class PuBadge extends StatelessWidget {
  final PuRollupRow? roll;
  const PuBadge({super.key, required this.roll});

  @override
  Widget build(BuildContext context) {
    final r = roll;
    if (r == null || r.entriesCount == 0) {
      return const Icon(Icons.chevron_right);
    }
    if (r.conflictFlag) {
      return const Chip(
        avatar: Icon(Icons.warning_amber_rounded,
            color: Colors.white, size: 18),
        label: Text('Conflict', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
      );
    }
    if (r.crossChecked) {
      return const Chip(
        avatar: Icon(Icons.verified, color: Colors.white, size: 18),
        label: Text('Cross-checked',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      );
    }
    if (r.duplicateFlag) {
      return Chip(
        avatar: const Icon(Icons.copy_all, color: Colors.white, size: 18),
        label: Text('${r.entriesCount} entries',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      );
    }
    return const Chip(
      avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
      label: Text('Recorded', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.teal,
    );
  }
}
