import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/main.dart';

void main() {
  testWidgets('shows the Weekra landing state', (tester) async {
    await tester.pumpWidget(const WeekraApp());

    expect(find.text('Weekra'), findsOneWidget);
    expect(find.text('Your week, clearly.'), findsOneWidget);
  });
}

