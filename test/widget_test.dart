import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';

void main() {
  testWidgets('shows the Weekra week view', (tester) async {
    await tester.pumpWidget(const WeekraApp());

    expect(find.text('WEEKRA  /  YOUR WEEK'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('opens the new event preview', (tester) async {
    await tester.pumpWidget(const WeekraApp());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsOneWidget);
    expect(find.text('Event editing is the next MVP slice.'), findsOneWidget);
  });
}
