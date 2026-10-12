import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'record engineering scan latency on a fixed deidentified fixture',
    () async {
      const service = LocalScanAnalysisService();
      const path = 'test/fixtures/urs10t_handle_reference.jpg';
      final times = <int>[];
      for (var i = 0; i < 4; i++) {
        final watch = Stopwatch()..start();
        final result = await service.analyze(imagePath: path);
        expect(result.rows.length, 10);
        watch.stop();
        if (i > 0) times.add(watch.elapsedMilliseconds);
      }
      final output = Platform.environment['URITECT_BENCHMARK_OUTPUT'];
      final report = {
        'fixture': path,
        'runs_ms': times,
        'scope':
            'Host Flutter test runtime, warm runs, same fixture; not Android device latency',
        'median_ms': (List<int>.of(times)..sort())[1],
      };
      if (output != null) File(output).writeAsStringSync(jsonEncode(report));
      // ignore: avoid_print
      print('URITECT_BENCHMARK ${jsonEncode(report)}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
