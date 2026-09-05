import 'package:ec8a_scanner/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _emailField = find.descendant(
  of: find.byType(TextFormField).at(0),
  matching: find.byType(EditableText),
);
final _passwordField = find.descendant(
  of: find.byType(TextFormField).at(1),
  matching: find.byType(EditableText),
);

Future<void> _signOut(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Sign out'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(_emailField, 'agent@ndc.ng');
  await tester.enterText(_passwordField, 'password123');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  testWidgets('LoginScreen renders email/password fields and sign-in button',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Demo mode starts signed in - sign out to see login screen
    await _signOut(tester);

    // Should show the app title and login fields
    expect(find.text('EC8A Scanner'), findsOneWidget);
    expect(find.text('NDC polling unit results capture'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('LoginScreen validates email format', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Sign out to see login screen
    await _signOut(tester);

    // Enter invalid email
    await tester.enterText(_emailField, 'notanemail');
    await tester.enterText(_passwordField, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter email'), findsOneWidget);
  });

  testWidgets('LoginScreen validates password length', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Sign out to see login screen
    await _signOut(tester);

    await tester.enterText(_emailField, 'test@example.com');
    await tester.enterText(_passwordField, '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Min 6 characters'), findsOneWidget);
  });

  testWidgets('LoginScreen demo mode signs in and navigates to home',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: Ec8aScannerApp()),
    );
    await tester.pumpAndSettle();

    // Sign out first to get to login screen
    await _signOut(tester);
    expect(find.text('EC8A Scanner'), findsOneWidget);

    // Sign in
    await _signIn(tester);

    // Should now show the home shell with navigation bar
    expect(find.text('My Polling Units'), findsOneWidget);
    expect(find.text('Tally'), findsOneWidget);
    // Demo mode seeds admin role, so Admin tab should be visible
    expect(find.text('Admin'), findsOneWidget);
  });
}
