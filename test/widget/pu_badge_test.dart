import 'package:ec8a_scanner/data/models.dart';
import 'package:ec8a_scanner/features/home/pu_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PuRollupRow _rollup({
  required int entries,
  bool duplicate = false,
  bool crossChecked = false,
  bool conflict = false,
}) =>
    PuRollupRow(
      puId: 'pu1',
      puCode: '25/06/01/001',
      puName: 'Kabusa I',
      state: 'FCT',
      lga: 'Municipal',
      ward: 'Kabusa',
      latestSubmissionId: 's1',
      latestTeamId: 't1',
      latestAt: null,
      sheetTotalVotesCast: 291,
      accreditedVoters: 310,
      entriesCount: entries,
      duplicateFlag: duplicate,
      crossChecked: crossChecked,
      conflictFlag: conflict,
    );

void main() {
  testWidgets('PuBadge shows chevron when no entries', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PuBadge(roll: null),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('PuBadge shows "Recorded" for single entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuBadge(
            roll: _rollup(entries: 1),
          ),
        ),
      ),
    );

    expect(find.text('Recorded'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('PuBadge shows "Cross-checked" for agreeing duplicates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuBadge(
            roll: _rollup(entries: 2, duplicate: true, crossChecked: true),
          ),
        ),
      ),
    );

    expect(find.text('Cross-checked'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('PuBadge shows "Conflict" for disagreeing duplicates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuBadge(
            roll: _rollup(entries: 2, duplicate: true, conflict: true),
          ),
        ),
      ),
    );

    expect(find.text('Conflict'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('PuBadge shows "N entries" for undecided duplicates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PuBadge(
            roll: _rollup(entries: 3, duplicate: true),
          ),
        ),
      ),
    );

    expect(find.text('3 entries'), findsOneWidget);
    expect(find.byIcon(Icons.copy_all), findsOneWidget);
  });
}
