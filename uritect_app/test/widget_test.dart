import 'package:flutter_test/flutter_test.dart';

import 'package:uritect_app/main.dart';

void main() {
  testWidgets('Uritect app renders landing experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('ENTER'), findsOneWidget);
  });
}
