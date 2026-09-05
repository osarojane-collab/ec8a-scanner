import 'package:ec8a_scanner/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _emailField = find.descendant(
  of: find.byType(TextFormField).at(0),
  matching: find.byType(EditableText),
);
final _passwordField = find.descendant(
  of: find.byType(TextFormField).at(1),
  matching: find.byType(EditableText),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('EC8A Scanner End-to-End', () {
    testWidgets('full flow: view units → submit result → check tally',
        (tester) async {
      // Launch the app (demo mode starts signed in)
      await tester.pumpWidget(
        const ProviderScope(child: Ec8aScannerApp()),
      );
      await tester.pumpAndSettle();

      // ---- HOME SCREEN ----
      expect(find.text('My Polling Units'), findsOneWidget);
      // Demo seeds 6 PUs, first 3 assigned to user's team
      expect(find.textContaining('25/06/01/001'), findsOneWidget);

      // ---- NAVIGATE TO TALLY ----
      await tester.tap(find.text('Tally'));
      await tester.pumpAndSettle();
      expect(find.text('Overall Tally'), findsOneWidget);

      // ---- GO BACK TO HOME ----
      await tester.tap(find.text('My Units'));
      await tester.pumpAndSettle();
      expect(find.text('My Polling Units'), findsOneWidget);

      // ---- OPEN CAPTURE FOR A PU ----
      await tester.tap(find.textContaining('25/06/01/004'));
      await tester.pumpAndSettle();

      // Capture screen shows camera or error, with action buttons
      expect(find.text('Enter manually'), findsOneWidget);

      // ---- MANUAL ENTRY ----
      await tester.tap(find.text('Enter manually'));
      await tester.pumpAndSettle();

      // ---- REVIEW SCREEN ----
      expect(find.textContaining('Review'), findsOneWidget);
      expect(find.text('Party votes'), findsOneWidget);

      // ---- SUBMIT (team should auto-select in demo) ----
      await tester.tap(find.widgetWithText(FilledButton, 'Submit results'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show success snackbar
      expect(find.textContaining('Submitted'), findsOneWidget);

      // ---- CHECK TALLY UPDATED ----
      // Navigate back to home then tally
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tally'));
      await tester.pumpAndSettle();
      expect(find.text('Overall Tally'), findsOneWidget);
    });

    testWidgets('navigate to PU detail from dashboard', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: Ec8aScannerApp()),
      );
      await tester.pumpAndSettle();

      // Demo mode starts signed in - go to Tally
      await tester.tap(find.text('Tally'));
      await tester.pumpAndSettle();

      // Tap on a recorded PU
      await tester.tap(find.textContaining('25/06/01/001'));
      await tester.pumpAndSettle();

      // Should see detail screen (title is "code — entries")
      expect(find.textContaining('— entries'), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Overall Tally'), findsOneWidget);
    });

    testWidgets('sign out and back in', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: Ec8aScannerApp()),
      );
      await tester.pumpAndSettle();

      // Demo mode starts signed in
      expect(find.text('My Polling Units'), findsOneWidget);

      // Sign out
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Back at login
      expect(find.text('EC8A Scanner'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

      // Sign back in
      await tester.enterText(_emailField, 'agent@ndc.ng');
      await tester.enterText(_passwordField, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('My Polling Units'), findsOneWidget);
    });
  });
}
