import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/models/scan_analysis_failure.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';

img.Image texturedStrip({bool secondStrip = false, bool missingPad = false}) {
  final image = img.Image(width: 480, height: 720);
  // A varying background defeats the constant-background assumption.
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final level = 105 + ((x ~/ 40 + y ~/ 45) % 3) * 12;
      image.setPixelRgb(x, y, level + 15, level + 5, level);
    }
  }
  const colors = [
    [210, 160, 80],
    [215, 130, 160],
    [180, 160, 90],
    [200, 170, 70],
    [200, 120, 80],
    [205, 150, 65],
    [170, 130, 70],
    [185, 125, 100],
    [195, 160, 100],
    [90, 185, 155],
  ];
  for (final left in [220, if (secondStrip) 330]) {
    img.fillRect(
      image,
      x1: left,
      y1: 50,
      x2: left + 26,
      y2: 695,
      color: img.ColorRgb8(245, 248, 250),
    );
    for (var i = 0; i < 10; i++) {
      if (missingPad && i == 5) continue;
      final c = colors[i];
      img.fillRect(
        image,
        x1: left + 1,
        y1: 50 + i * 53,
        x2: left + 25,
        y2: 82 + i * 53,
        color: img.ColorRgb8(c[0], c[1], c[2]),
      );
    }
  }
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyzer = LocalScanAnalysisService();
  test(
    'textured background permits ten-pad localization without forcing classification',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'uritect_texture_',
      );
      try {
        final file = File('${directory.path}/strip.png');
        await file.writeAsBytes(img.encodePng(texturedStrip()));
        try {
          final scan = await analyzer.analyze(imagePath: file.path);
          expect(scan.padsDetected, 10);
        } on ScanAnalysisFailure catch (error) {
          expect(error.code, 'LOW_CONFIDENCE');
          expect(error.padsDetected, 10);
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  for (final multi in [false, true]) {
    test(
      'textured background rejects ${multi ? 'two strips' : 'a missing pad'}',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'uritect_texture_',
        );
        try {
          final file = File('${directory.path}/invalid.png');
          await file.writeAsBytes(
            img.encodePng(
              texturedStrip(secondStrip: multi, missingPad: !multi),
            ),
          );
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
      },
    );
  }
}
