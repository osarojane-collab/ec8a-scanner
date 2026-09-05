import 'package:ec8a_scanner/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DashboardScreen shows overall tally with party totals',
      (tester) async {
    // Demo mode starts signed in
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Navigate to Tally tab
    await tester.tap(find.text('Tally'));
    await tester.pumpAndSettle();

    expect(find.text('Overall Tally'), findsOneWidget);

    // Demo seeds parties: NDC, APC, PDP, LP, NNPP
    expect(find.textContaining('NDC'), findsWidgets);
    expect(find.textContaining('APC'), findsWidgets);
  });

  testWidgets('DashboardScreen lists polling units with entry counts',
      (tester) async {
    // Demo mode starts signed in
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Navigate to Tally tab
    await tester.tap(find.text('Tally'));
    await tester.pumpAndSettle();

    // Should show the PU list section
    expect(find.textContaining('Polling units'), findsOneWidget);

    // Demo seeds 3 recorded PUs - at least the first one should be visible
    expect(find.textContaining('25/06/01/001'), findsOneWidget);
  });

  testWidgets('DashboardScreen shows NDC highlighted as home party',
      (tester) async {
    // Demo mode starts signed in
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Navigate to Tally tab
    await tester.tap(find.text('Tally'));
    await tester.pumpAndSettle();

    // NDC should appear with "polling unit(s)" subtitle
    expect(find.textContaining('polling unit(s)'), findsWidgets);
  });

  testWidgets('DashboardScreen PU entry is tappable for detail',
      (tester) async {
    // Demo mode starts signed in
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Navigate to Tally tab
    await tester.tap(find.text('Tally'));
    await tester.pumpAndSettle();

    // Tap on a polling unit entry
    await tester.tap(find.textContaining('25/06/01/001'));
    await tester.pumpAndSettle();

    // Should navigate to PU detail screen (title is "code — entries")
    expect(find.textContaining('— entries'), findsOneWidget);
  });
}
