import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/local_scan_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyzer = LocalScanAnalysisService();
  const source = 'test/fixtures/rmx3933_white_background_20261007.jpg';
  test('real RMX pale-pad capture localizes ten measured pads', () async {
    final result = await analyzer.analyze(imagePath: source);
    expect(result.padsDetected, 10);
    expect(result.isReliableForInterpretation, isTrue);
    // This verifies execution and gating, not clinical correctness of labels.
  });
  test(
    'pale-pad fallback preserves analyte order when rotated',
    () async {
      final original = img.decodeImage(await File(source).readAsBytes())!;
      final baseline = await analyzer.analyze(imagePath: source);
      final directory = await Directory.systemTemp.createTemp('uritect_pale_');
      try {
        for (final angle in [90, 180]) {
          final file = File('${directory.path}/rotated_$angle.png');
          await file.writeAsBytes(
            img.encodePng(img.copyRotate(original, angle: angle)),
          );
          final scan = await analyzer.analyze(imagePath: file.path);
          expect(
            scan.rows.map((r) => r.result),
            baseline.rows.map((r) => r.result),
            reason: 'Rotation $angle',
          );
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
