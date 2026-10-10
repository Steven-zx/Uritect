import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/services/local_scan_analysis_service.dart';
import 'package:uritect_app/models/scan_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const imagePath = String.fromEnvironment('URITECT_PHONE_IMAGE');
  const outputPath = String.fromEnvironment('URITECT_PHONE_OUTPUT');
  test(
    'reproduce the identified phone capture without reference-label claims',
    () async {
      final output = <String, dynamic>{'image_path': imagePath};
      final locations = <ScanLocalization>[];
      try {
        final scan = await const LocalScanAnalysisService().analyze(
          imagePath: imagePath,
          onLocalization: locations.add,
        );
        output['scan'] = scan.toJson();
        output['accepted'] = scan.isReliableForInterpretation;
      } catch (error) {
        output['accepted'] = false;
        output['error'] = error.toString();
      }
      if (locations.isNotEmpty) {
        final last = locations.last;
        await File('$outputPath.preview.jpg').writeAsBytes(last.preview);
        output['orientation'] = last.orientation;
        output['regions'] = [
          for (final r in last.regions)
            {
              'label': r.label,
              'left': r.rect.left,
              'top': r.rect.top,
              'width': r.rect.width,
              'height': r.rect.height,
            },
        ];
      }
      await File(
        outputPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(output));
      // ignore: avoid_print
      print(jsonEncode(output));
    },
    skip: imagePath.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
