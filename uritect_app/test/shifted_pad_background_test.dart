import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/models/scan_analysis_failure.dart';
import 'package:uritect_app/models/scan_localization.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'background above the tip cannot shift the ten analyte assignments',
    () async {
      final events = <ScanLocalization>[];
      try {
        await const LocalScanAnalysisService().analyze(
          imagePath: 'test/fixtures/shifted_pad_background_reference.png',
          onLocalization: events.add,
        );
      } on ScanAnalysisFailure catch (error) {
        if (error.code == 'PAD_BOUNDARIES_UNCLEAR') {
          expect(events.where((e) => e.regions.isNotEmpty), isEmpty);
          return;
        }
        expect(
          error.code,
          isIn(['LOW_CONFIDENCE', 'OUTSIDE_TRAINING_SUPPORT']),
        );
      } on StateError catch (error) {
        expect(error.message.toString(), contains('INVALID_IMAGE'));
        expect(events.where((e) => e.regions.isNotEmpty), isEmpty);
        return;
      }
      final located = events.lastWhere((e) => e.regions.length == 10);
      final leu = located.regions.first;
      final glu = located.regions.last;
      expect(leu.label, 'LEU');
      expect(glu.label, 'GLU');
      // The physical strip begins below y=100 in this measured 1100px frame.
      // The old detector sampled plain background above it as the first pad.
      expect(leu.rect.center.dy, greaterThan(100));
      final preview = img.decodeImage(located.preview)!;
      final pixel = preview.getPixel(
        glu.rect.center.dx.round(),
        glu.rect.center.dy.round(),
      );
      expect(
        pixel.g,
        greaterThan(pixel.r + 20),
        reason:
            'GLU must sample the teal pad beside the handle, not the pale preceding pad',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
