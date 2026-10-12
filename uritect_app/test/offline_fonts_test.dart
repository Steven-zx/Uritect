import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uritect_app/main.dart' as app;

void main() {
  testWidgets(
    'fresh startup loads bundled theme fonts with fetching disabled',
    (tester) async {
      app.main();
      await tester.pump();
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        for (final name in [
          'Poppins-Regular',
          'Inter-Regular',
          'Inter-Medium',
          'Inter-SemiBold',
          'Poppins-Medium',
          'Poppins-SemiBold',
          'Poppins-Bold',
        ]) {
          final path = 'assets/fonts/$name.ttf';
          expect(manifest.listAssets(), contains(path));
          final bytes = await rootBundle.load(path);
          expect(bytes.lengthInBytes, greaterThan(100000));
        }
      });
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2500));
    },
  );
}
