import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_localization.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyzer = LocalScanAnalysisService();
  const source = 'test/fixtures/rmx3933_white_background_20261007.jpg';
  Future<ScanLocalization> locate(String path) async {
    final locations = <ScanLocalization>[];
    try {
      final scan = await analyzer.analyze(
        imagePath: path,
        onLocalization: locations.add,
      );
      expect(scan.stripDirectionVerified, isTrue);
      expect(scan.modelDirectionReviewed, isTrue);
      expect(scan.rows.length, 10);
    } on ScanAnalysisFailure catch (error) {
      expect(error.code, isIn(['LOW_CONFIDENCE', 'OUTSIDE_TRAINING_SUPPORT']));
      expect(error.padsDetected, 10);
    }
    return locations.last;
  }

  test(
    'real RMX pale-pad capture localizes physical pads with correct analyte roles',
    () async {
      final evidence = await locate(source);
      expect(evidence.regions.length, 10);
      final glu = evidence.regions.last;
      final preview = img.decodeImage(evidence.preview)!;
      final pixel = preview.getPixel(
        glu.rect.center.dx.round(),
        glu.rect.center.dy.round(),
      );
      expect(glu.label, 'GLU');
      expect(pixel.g, greaterThan(pixel.r + 20));
    },
  );
  test(
    'pale-pad fallback keeps measured physical regions upright in all rotations',
    () async {
      final original = img.decodeImage(await File(source).readAsBytes())!;
      final directory = await Directory.systemTemp.createTemp('uritect_pale_');
      try {
        for (final angle in [90, 180, -90]) {
          final file = File('${directory.path}/$angle.png');
          await file.writeAsBytes(
            img.encodePng(img.copyRotate(original, angle: angle)),
          );
          final evidence = await locate(file.path);
          expect(
            evidence.regions.first.rect.top,
            lessThan(evidence.regions.last.rect.top),
          );
          final glu = evidence.regions.last;
          final preview = img.decodeImage(evidence.preview)!;
          final pixel = preview.getPixel(
            glu.rect.center.dx.round(),
            glu.rect.center.dy.round(),
          );
          expect(pixel.g, greaterThan(pixel.r + 20));
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test('pale-pad fallback does not fill a cropped-off endpoint pad', () async {
    final original = img.decodeImage(await File(source).readAsBytes())!;
    final cut = (original.height * .18).round();
    final cropped = img.copyCrop(
      original,
      x: 0,
      y: cut,
      width: original.width,
      height: original.height - cut,
    );
    final directory = await Directory.systemTemp.createTemp(
      'uritect_partial_pale_',
    );
    try {
      final file = File('${directory.path}/partial.png');
      await file.writeAsBytes(img.encodePng(cropped));
      await expectLater(
        analyzer.analyze(imagePath: file.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('INVALID_IMAGE'),
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
