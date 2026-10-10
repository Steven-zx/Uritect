import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/main.dart';
import 'package:uritect_app/pages/root_page.dart';

void main() {
  testWidgets('first Flutter frame is dashboard with no second launch screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(RootPage), findsOneWidget);
    expect(find.text('START SCAN'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(RootPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
