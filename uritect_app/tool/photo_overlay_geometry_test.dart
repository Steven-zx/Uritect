import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/models/scan_localization.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manifestPath = String.fromEnvironment('URITECT_RUNTIME_AUDIT');
  test(
    'actual preview and measured regions share orientation, EXIF and resize coordinates',
    () async {
      final manifest =
          jsonDecode(await File(manifestPath).readAsString()) as Map;
      final source = img.bakeOrientation(
        img.decodeImage(
          await File(manifest['cases'][2]['image_path']).readAsBytes(),
        )!,
      );
      final temporary = await Directory.systemTemp.createTemp(
        'uritect_geometry_',
      );
      final report = <Map<String, Object>>[];
      try {
        for (final angle in [0, 90, 180, -90, 6]) {
          final input = angle == 6
              ? img.Image.from(source)
              : img.copyRotate(source, angle: angle);
          if (angle == 6) input.exif.imageIfd.orientation = 6;
          final file = File(
            '${temporary.path}/rotation_$angle.${angle == 6 ? 'jpg' : 'png'}',
          );
          await file.writeAsBytes(
            angle == 6
                ? img.encodeJpg(input, quality: 95)
                : img.encodePng(input),
          );
          final events = <ScanLocalization>[];
          try {
            await const LocalScanAnalysisService().analyze(
              imagePath: file.path,
              onLocalization: events.add,
            );
          } catch (_) {
            // Localization can succeed while confidence/support still rejects.
          }
          expect(events, isNotEmpty);
          final decoded = img.bakeOrientation(
            img.decodeImage(await file.readAsBytes())!,
          );
          final longest = math.max(decoded.width, decoded.height);
          final base = longest <= 1100
              ? decoded
              : img.copyResize(
                  decoded,
                  width: math.max(1, (decoded.width * 1100 / longest).round()),
                  height: math.max(
                    1,
                    (decoded.height * 1100 / longest).round(),
                  ),
                  interpolation: img.Interpolation.average,
                );
          for (final evidence in events) {
            final orientation = evidence.orientation;
            final expected = orientation.startsWith('rot90_cw')
                ? img.copyRotate(base, angle: 90)
                : orientation.startsWith('rot90_ccw')
                ? img.copyRotate(base, angle: -90)
                : orientation.startsWith('rot180')
                ? img.copyRotate(base, angle: 180)
                : base;
            final preview = img.decodeImage(evidence.preview)!;
            expect(preview.width, expected.width);
            expect(preview.height, expected.height);
            double error = 0;
            int count = 0;
            for (var y = 10; y < preview.height - 10; y += 17) {
              for (var x = 10; x < preview.width - 10; x += 17) {
                final a = preview.getPixel(x, y);
                final b = expected.getPixel(x, y);
                error +=
                    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
                count += 3;
              }
            }
            expect(
              error / count,
              lessThan(12),
              reason: 'Display JPEG must represent the selected detector image',
            );
            for (final region in evidence.regions) {
              expect(region.rect.left, greaterThanOrEqualTo(0));
              expect(region.rect.top, greaterThanOrEqualTo(0));
              expect(region.rect.right, lessThanOrEqualTo(preview.width));
              expect(region.rect.bottom, lessThanOrEqualTo(preview.height));
            }
          }
          expect(
            events.last.regions.length,
            10,
            reason: 'Known development fixture must still localize',
          );
          report.add({
            'input_rotation': angle,
            'selected_orientation': events.last.orientation,
            'width': events.last.imageSize.width,
            'height': events.last.imageSize.height,
            'regions': events.last.regions.length,
          });
        }
        await File(
          '${File(manifest['output_path']).parent.path}/overlay_geometry.json',
        ).writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'scope': 'Engineering coordinate checks, not clinical validation',
            'cases': report,
          }),
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    skip: manifestPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
