import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Full app needs .env + Supabase bootstrap — covered by running the app.
  testWidgets('Material smoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('SoilGood'))),
    );
    expect(find.text('SoilGood'), findsOneWidget);
  });
}
