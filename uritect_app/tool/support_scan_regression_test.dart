import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/models/scan_localization.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manifestPath = String.fromEnvironment('URITECT_RUNTIME_AUDIT');
  test(
    'support guard development image regression',
    () async {
      final manifest =
          jsonDecode(await File(manifestPath).readAsString())
              as Map<String, dynamic>;
      final results = <Map<String, dynamic>>[];
      for (final item in manifest['cases'] as List) {
        final entry = <String, dynamic>{'event_id': item['event_id']};
        final events = <ScanLocalization>[];
        final watch = Stopwatch()..start();
        try {
          final scan = await const LocalScanAnalysisService().analyze(
            imagePath: item['image_path'],
            onLocalization: events.add,
          );
          entry['after'] = {
            'accepted': scan.isReliableForInterpretation,
            'status': scan.status,
            'rejection_code': scan.rejectionCode,
            'readings_available': scan.rows.length,
            'predictions': {for (final r in scan.rows) r.name: r.result},
            'analyte_confidences': scan.analyteConfidences,
            'nearest_training_distances': scan.nearestTrainingDistances,
            'elapsed_ms': watch.elapsedMilliseconds,
          };
        } catch (error) {
          entry['after'] = {
            'accepted': false,
            'rejection_reason': error.toString(),
            'rejection_code': error is ScanAnalysisFailure ? error.code : null,
            'elapsed_ms': watch.elapsedMilliseconds,
          };
        }
        expect(events, isNotEmpty);
        expect(events.first.regions, isEmpty);
        for (final evidence in events) {
          final preview = img.decodeImage(evidence.preview)!;
          expect(preview.width, evidence.imageSize.width);
          expect(preview.height, evidence.imageSize.height);
          expect(evidence.imageSize.longestSide, lessThanOrEqualTo(1100));
          if (evidence.regions.isNotEmpty) {
            expect(evidence.regions.length, 10);
            expect(evidence.regions.map((r) => r.label).toSet().length, 10);
          }
          for (final region in evidence.regions) {
            expect(region.rect.left, greaterThanOrEqualTo(0));
            expect(region.rect.top, greaterThanOrEqualTo(0));
            expect(region.rect.right, lessThanOrEqualTo(preview.width));
            expect(region.rect.bottom, lessThanOrEqualTo(preview.height));
          }
        }
        entry['localization'] = {
          'preview_events': events.length,
          'located_regions': events.last.regions.length,
          'width': events.last.imageSize.width,
          'height': events.last.imageSize.height,
        };
        results.add(entry);
        // ignore: avoid_print
        print(
          'Support regression ${results.length}: ${item['event_id']} accepted=${(entry['after'] as Map)['accepted']}',
        );
      }
      await File(manifest['output_path']).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'scope':
              'Retrospective development regression, not independent clinical validation',
          'cases': results,
        }),
      );
      expect(results.length, (manifest['cases'] as List).length);
    },
    skip: manifestPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
