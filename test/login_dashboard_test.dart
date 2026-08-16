import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquis_rm_flutter/main.dart';

void main() {
  testWidgets('Login as meter reader renders dashboard without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const AquisApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'reader');
    await tester.enterText(find.byType(TextField).at(1), 'reader123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Completed'), findsAtLeastNWidgets(1));
    expect(find.text('Queue'), findsAtLeastNWidgets(1));
    expect(find.text('Unrecorded'), findsOneWidget);
    expect(find.text('Corrections'), findsOneWidget);
    expect(find.text('Failed'), findsAtLeastNWidgets(1));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Residential'), findsWidgets);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unrecorded').last);
    await tester.pumpAndSettle();
    expect(find.text('A. Bonifacio St., Poblacion'), findsOneWidget);
  });
}
