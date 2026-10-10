import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyzer = LocalScanAnalysisService();
  test(
    'camera and gallery copies of identical photo give identical accepted results',
    () async {
      final source = File('test/fixtures/cabatuan_028_cool.jpg');
      final dir = await Directory.systemTemp.createTemp('uritect_parity_');
      try {
        final camera = await source.copy('${dir.path}/camera.jpg');
        final gallery = await source.copy('${dir.path}/gallery.jpg');
        final first = await analyzer.analyze(imagePath: camera.path);
        final second = await analyzer.analyze(imagePath: gallery.path);
        expect(first.isReliableForInterpretation, isTrue);
        expect(first.padsDetected, 10);
        expect(second.padsDetected, 10);
        expect(
          first.rows.map((r) => r.result),
          second.rows.map((r) => r.result),
        );
        expect(first.analyteConfidences, second.analyteConfidences);
        expect(first.modelVersion, second.modelVersion);
        expect(
          first.pipelineVersion,
          'android_markerless_json_knn_v4_support_20261010',
        );
        expect(
          ScanResult.fromJson(first.toJson()).pipelineVersion,
          first.pipelineVersion,
        );
        final legacy = first.toJson()..remove('pipeline_version');
        expect(ScanResult.fromJson(legacy).pipelineVersion, isNull);
      } finally {
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'sideways and upside-down strips preserve analyte ordering',
    () async {
      final original = File('test/fixtures/cabatuan_028_cool.jpg');
      final image = img.decodeImage(await original.readAsBytes())!;
      final baseline = await analyzer.analyze(imagePath: original.path);
      final dir = await Directory.systemTemp.createTemp('uritect_orientation_');
      try {
        for (final angle in [90, 180]) {
          final file = File('${dir.path}/rotated_$angle.png');
          await file.writeAsBytes(
            img.encodePng(img.copyRotate(image, angle: angle)),
          );
          final result = await analyzer.analyze(imagePath: file.path);
          expect(
            result.rows.map((r) => r.result),
            baseline.rows.map((r) => r.result),
            reason: 'Rotation $angle',
          );
        }
      } finally {
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'two visible strips are rejected instead of silently choosing one',
    () async {
      final source = img.decodeImage(
        await File('test/fixtures/cabatuan_028_cool.jpg').readAsBytes(),
      )!;
      final pair = img.Image(width: source.width * 2, height: source.height);
      img.compositeImage(pair, source);
      img.compositeImage(pair, source, dstX: source.width);
      final dir = await Directory.systemTemp.createTemp('uritect_multi_');
      try {
        final file = File('${dir.path}/two_strips.png');
        await file.writeAsBytes(img.encodePng(pair));
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
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'actual decoder rejects invalid and blank files without producing normal results',
    () async {
      final dir = await Directory.systemTemp.createTemp('uritect_invalid_');
      try {
        final broken = File('${dir.path}/broken.jpg');
        await broken.writeAsString('not a photo');
        await expectLater(
          analyzer.analyze(imagePath: broken.path),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'reason',
              contains('INVALID_IMAGE'),
            ),
          ),
        );
        final blank = File('${dir.path}/blank.png');
        final image = img.Image(width: 360, height: 480);
        img.fill(image, color: img.ColorRgb8(255, 255, 255));
        await blank.writeAsBytes(img.encodePng(image));
        await expectLater(
          analyzer.analyze(imagePath: blank.path),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'reason',
              contains('INVALID_IMAGE'),
            ),
          ),
        );
        await expectLater(
          analyzer.analyze(imagePath: '${dir.path}/missing.jpg'),
          throwsA(isA<StateError>()),
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
