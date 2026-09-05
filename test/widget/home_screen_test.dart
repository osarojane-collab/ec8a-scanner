import 'package:ec8a_scanner/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen shows polling units after demo sign-in',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Demo mode starts signed in - should show home screen with polling units
    expect(find.text('My Polling Units'), findsOneWidget);

    // Demo seeds 6 polling units, first 3 assigned to user's team
    expect(find.textContaining('25/06/01/001'), findsOneWidget);
    expect(find.textContaining('Kabusa I - Open Space'), findsOneWidget);
  });

  testWidgets('HomeScreen shows PU status badges', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Demo seeds: PU1 = Recorded, PU2 = Cross-checked, PU3 = Conflict
    expect(find.text('Recorded'), findsOneWidget);
    expect(find.text('Cross-checked'), findsOneWidget);
    expect(find.text('Conflict'), findsOneWidget);
  });

  testWidgets('HomeScreen navigation bar switches tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Tap Tally tab
    await tester.tap(find.text('Tally'));
    await tester.pumpAndSettle();

    expect(find.text('Overall Tally'), findsOneWidget);

    // Tap Admin tab (demo user is admin)
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsWidgets);
  });

  testWidgets('HomeScreen sign out returns to login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Tap sign out
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Should return to login screen
    expect(find.text('EC8A Scanner'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
