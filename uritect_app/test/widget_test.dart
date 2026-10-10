import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uritect_app/main.dart';
import 'package:uritect_app/pages/root_page.dart';

void main() {
  testWidgets('Uritect launch opens dashboard automatically', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('Preparing offline screening…'), findsOneWidget);
    expect(find.text('ENTER'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RootPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
