import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import '_baseline_local_scan_analysis_service.dart' as baseline;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manifestPath = String.fromEnvironment('URITECT_RUNTIME_AUDIT');
  test(
    'development image regression before and after preprocessing fix',
    () async {
      final manifest =
          jsonDecode(await File(manifestPath).readAsString())
              as Map<String, dynamic>;
      final cases = manifest['cases'] as List;
      final outputs = <Map<String, dynamic>>[];
      for (final item in cases) {
        final record = <String, dynamic>{
          'event_id': item['event_id'],
          'source_zip': item['source_zip'],
          'light_kelvin': item['light_kelvin'],
          'reference_labels': item['reference_labels'],
        };
        for (final stage in ['before', 'after']) {
          final watch = Stopwatch()..start();
          try {
            final scan = stage == 'before'
                ? await const baseline.LocalScanAnalysisService().analyze(
                    imagePath: item['image_path'],
                  )
                : await const LocalScanAnalysisService().analyze(
                    imagePath: item['image_path'],
                  );
            record[stage] = {
              'accepted': scan.isReliableForInterpretation,
              'predictions': {
                for (final row in scan.rows) row.name: row.result,
              },
              'analyte_confidences': scan.analyteConfidences,
              'elapsed_ms': watch.elapsedMilliseconds,
            };
          } catch (error) {
            record[stage] = {
              'accepted': false,
              'rejection_reason': error.toString(),
              'elapsed_ms': watch.elapsedMilliseconds,
            };
          }
        }
        outputs.add(record);
        // ignore: avoid_print
        print('Runtime regression ${outputs.length}/${cases.length}: ${item['event_id']} before=${(record['before'] as Map)['accepted']} after=${(record['after'] as Map)['accepted']}');
      }
      final output = File(manifest['output_path']);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'scope':
              'retrospective development image regression; not independent final validation',
          'cases': outputs,
          'model_changed': false,
        }),
      );
      expect(outputs.length, cases.length);
    },
    skip: manifestPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
