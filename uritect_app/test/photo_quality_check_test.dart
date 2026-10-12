import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/photo_quality_check.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = {
    'IMAGE_TOO_DARK': img.ColorRgb8(10, 10, 10),
    'IMAGE_OVEREXPOSED': img.ColorRgb8(255, 255, 255),
    'IMAGE_BLANK': img.ColorRgb8(150, 150, 150),
    'IMAGE_BLURRED': img.ColorRgb8(180, 150, 40),
  };
  for (final entry in cases.entries) {
    test('early rejection gives actionable ${entry.key} reason', () async {
      final image = img.Image(width: 320, height: 480);
      img.fill(image, color: entry.value);
      expect(
        () => PhotoQualityCheck.validate(image),
        throwsA(
          isA<ScanAnalysisFailure>().having((e) => e.code, 'code', entry.key),
        ),
      );
      final directory = await Directory.systemTemp.createTemp(
        'uritect_quality_',
      );
      try {
        final file = File('${directory.path}/photo.png');
        await file.writeAsBytes(img.encodePng(image));
        final stages = <String>[];
        final previews = <Object>[];
        await expectLater(
          const LocalScanAnalysisService().analyze(
            imagePath: file.path,
            onProgress: (_, stage) => stages.add(stage),
            onLocalization: previews.add,
          ),
          throwsA(
            isA<ScanAnalysisFailure>().having((e) => e.code, 'code', entry.key),
          ),
        );
        expect(stages, contains('checking_image_quality'));
        expect(stages, isNot(contains('locating_strip')));
        expect(previews, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }
  test(
    'a clear reference photo passes early quality, without implying valid classification',
    () {
      final photo = img.decodeImage(
        File('test/fixtures/urs10t_handle_reference.jpg').readAsBytesSync(),
      )!;
      expect(() => PhotoQualityCheck.validate(photo), returnsNormally);
    },
  );
}
