import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/main.dart';
import 'package:uritect_app/pages/root_page.dart';
import 'package:uritect_app/pages/app_splash_page.dart';

void main() {
  testWidgets('opening screen replaces itself with the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(AppSplashPage), findsOneWidget);
    expect(find.text('Preparing offline screening…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(RootPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing splash cancels pending navigation', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
