import 'package:flutter_test/flutter_test.dart';
import 'package:aquis_rm_flutter/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AquisApp());
    expect(find.text('AQUIS'), findsOneWidget);
  });
}
