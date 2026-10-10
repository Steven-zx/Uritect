import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';
import 'package:uritect_app/models/scan_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const analyzer = LocalScanAnalysisService();
  Future<ScanLocalization> locate(String path) async {
    final events = <ScanLocalization>[];
    try {
      final scan = await analyzer.analyze(
        imagePath: path,
        onLocalization: events.add,
      );
      expect(scan.stripDirectionVerified, isTrue);
      expect(scan.modelDirectionReviewed, isTrue);
      expect(scan.rows.length, 10);
    } on ScanAnalysisFailure catch (error) {
      expect(error.code, isIn(['LOW_CONFIDENCE', 'OUTSIDE_TRAINING_SUPPORT']));
      expect(error.padsDetected, 10);
    }
    final located = events.where((event) => event.regions.isNotEmpty).toList();
    expect(
      located.map((event) => event.regions.length),
      List.generate(10, (i) => i + 1),
    );
    for (final event in located) {
      expect(event.preview, same(located.first.preview));
      expect(event.orientation, located.first.orientation);
      expect(
        event.regions.map((region) => region.label),
        located.last.regions
            .take(event.regions.length)
            .map((region) => region.label),
      );
    }
    return events.last;
  }

  test(
    'camera/gallery locate the same physical pads with corrected experimental classification',
    () async {
      final dir = await Directory.systemTemp.createTemp('uritect_parity_');
      try {
        final original = File('test/fixtures/urs10t_handle_reference.jpg');
        final camera = await original.copy('${dir.path}/camera.jpg');
        final gallery = await original.copy('${dir.path}/gallery.jpg');
        final first = await locate(camera.path);
        final second = await locate(gallery.path);
        expect(
          first.regions.map((r) => r.rect),
          second.regions.map((r) => r.rect),
        );
        expect(first.regions.length, 10);
      } finally {
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'all rotations assign LEU at the physical tip and GLU next to the handle',
    () async {
      final image = img.decodeImage(
        await File('test/fixtures/urs10t_handle_reference.jpg').readAsBytes(),
      )!;
      final dir = await Directory.systemTemp.createTemp('uritect_direction_');
      try {
        for (final angle in [0, 90, 180, -90]) {
          final file = File('${dir.path}/$angle.png');
          await file.writeAsBytes(
            img.encodePng(img.copyRotate(image, angle: angle)),
          );
          final evidence = await locate(file.path);
          final leu = evidence.regions.firstWhere((r) => r.label == 'LEU');
          final glu = evidence.regions.firstWhere((r) => r.label == 'GLU');
          expect(leu.rect.top, lessThan(glu.rect.top));
          final preview = img.decodeImage(evidence.preview)!;
          final tip = preview.getPixel(
            leu.rect.center.dx.round(),
            leu.rect.center.dy.round(),
          );
          final last = preview.getPixel(
            glu.rect.center.dx.round(),
            glu.rect.center.dy.round(),
          );
          // These expectations are independently observed physical colors of this fixture,
          // not equality with the previous classifier's possibly reversed output.
          expect(
            last.g,
            greaterThan(last.r + 20),
            reason: 'GLU must sample the teal handle-adjacent pad',
          );
          expect(
            tip.r,
            greaterThan(last.r + 20),
            reason: 'LEU must sample the pale/rose tip pad',
          );
        }
      } finally {
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'two visible strips are rejected instead of silently choosing one',
    () async {
      final source = img.decodeImage(
        await File('test/fixtures/urs10t_handle_reference.jpg').readAsBytes(),
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
