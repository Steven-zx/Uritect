import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/pages/app_splash_page.dart';
import 'package:uritect_app/pages/root_page.dart';

void main() {
  testWidgets('reduced motion stays visible and opens one dashboard route', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppSplashPage(),
        ),
      ),
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(AppSplashPage),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
    expect(
      tester
          .widget<ScaleTransition>(
            find.byKey(const Key('splash-scanner-frame')),
          )
          .scale
          .value,
      1,
    );
    await tester.pump(const Duration(milliseconds: 2199));
    expect(find.byType(RootPage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(AppSplashPage), findsNothing);
    expect(find.byType(RootPage), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('small screen with large text remains usable', (tester) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: AppSplashPage(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Preparing offline screening…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone splash visual reference', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: RepaintBoundary(key: Key('splash'), child: AppSplashPage()),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const Key('splash')),
      matchesGoldenFile('goldens/app_splash_phone.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
