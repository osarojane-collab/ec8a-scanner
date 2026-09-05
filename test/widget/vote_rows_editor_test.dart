import 'package:ec8a_scanner/features/scan/ec8a_parser.dart';
import 'package:ec8a_scanner/features/scan/vote_rows_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VoteRowsEditor displays party abbreviations and votes',
      (tester) async {
    final controllers = {
      0: TextEditingController(text: '152'),
      1: TextEditingController(text: '87'),
    };
    final rows = [
      const ParsedRow(
          abbr: 'NDC',
          fullName: 'Nigeria Democratic Congress',
          votes: 152,
          confidence: 1.0),
      const ParsedRow(
          abbr: 'APC',
          fullName: 'All Progressives Congress',
          votes: 87,
          confidence: 1.0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteRowsEditor(
            rows: rows,
            controllers: controllers,
          ),
        ),
      ),
    );

    expect(find.text('NDC  Nigeria Democratic Congress'), findsOneWidget);
    expect(find.text('APC  All Progressives Congress'), findsOneWidget);
    expect(find.text('152'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
  });

  testWidgets('VoteRowsEditor tints low-confidence rows orange',
      (tester) async {
    final controllers = {
      0: TextEditingController(text: '21'),
    };
    final rows = [
      const ParsedRow(
          abbr: 'XYZ', fullName: 'Unknown Party', votes: 21, confidence: 0.5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteRowsEditor(
            rows: rows,
            controllers: controllers,
          ),
        ),
      ),
    );

    expect(find.text('low OCR confidence - check the photo'), findsOneWidget);
  });

  testWidgets('VoteRowsEditor shows remove button when onRemove is provided',
      (tester) async {
    var removedIndex = -1;
    final controllers = {
      0: TextEditingController(text: '152'),
      1: TextEditingController(text: '87'),
    };
    final rows = [
      const ParsedRow(
          abbr: 'NDC',
          fullName: 'Nigeria Democratic Congress',
          votes: 152,
          confidence: 1.0),
      const ParsedRow(
          abbr: 'APC',
          fullName: 'All Progressives Congress',
          votes: 87,
          confidence: 1.0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteRowsEditor(
            rows: rows,
            controllers: controllers,
            onRemove: (i) => removedIndex = i,
          ),
        ),
      ),
    );

    // Should show remove buttons
    expect(find.byIcon(Icons.close), findsNWidgets(2));

    // Tap remove on first row
    await tester.tap(find.byIcon(Icons.close).first);
    expect(removedIndex, 0);
  });

  testWidgets('VoteRowsEditor hides remove button when onRemove is null',
      (tester) async {
    final controllers = {
      0: TextEditingController(text: '152'),
    };
    final rows = [
      const ParsedRow(
          abbr: 'NDC',
          fullName: 'Nigeria Democratic Congress',
          votes: 152,
          confidence: 1.0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoteRowsEditor(
            rows: rows,
            controllers: controllers,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
