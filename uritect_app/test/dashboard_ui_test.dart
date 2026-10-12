import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/config/theme.dart';
import 'package:uritect_app/pages/home_page.dart';
import 'support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final largeText in [false, true]) {
    testWidgets(
      'focused dashboard is readable ${largeText ? 'with large text' : 'on phone'}',
      (tester) async {
        tester.view.physicalSize = largeText
            ? const Size(280, 640)
            : const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(largeText ? 1.8 : 1),
              ),
              child: const HomePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/photos/minUriLogo.png'),
            tester.element(find.byType(HomePage)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('START SCAN'), findsOneWidget);
        expect(find.text('Unlock saved history'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!largeText) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/dashboard_phone.png'),
          );
        }
        await tester.ensureVisible(find.text('Before You Scan'));
        await tester.tap(find.text('Before You Scan'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Show all ten pads'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
