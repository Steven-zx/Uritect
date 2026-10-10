import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/services/training_support_policy.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';

void main() {
  final model = File(
    'assets/production_semiquant_model.json',
  ).readAsStringSync();
  final text = File('assets/training_support_policy.json').readAsStringSync();
  test(
    'absolute support guard accepts training distances and boundary, rejects beyond independently of votes',
    () {
      final policy = TrainingSupportPolicy.fromText(model, text);
      for (final entry in policy.radii.entries) {
        policy.validate(entry.key, 0);
        policy.validate(entry.key, entry.value);
        for (final distance in [
          entry.value + .001,
          double.infinity,
          double.nan,
          -1.0,
        ]) {
          expect(
            () => policy.validate(entry.key, distance),
            throwsA(
              isA<ScanAnalysisFailure>()
                  .having((e) => e.code, 'code', 'OUTSIDE_TRAINING_SUPPORT')
                  .having((e) => e.padsDetected, 'located pads', 10),
            ),
          );
        }
      }
    },
  );
  test('policy is bound to exact model and exact analyte set', () {
    expect(
      () => TrainingSupportPolicy.fromText('$model ', text),
      throwsStateError,
    );
    final p = jsonDecode(text) as Map<String, dynamic>;
    (p['analytes'] as Map).remove('Nitrite');
    expect(
      () => TrainingSupportPolicy.fromText(model, jsonEncode(p)),
      throwsStateError,
    );
  });
}
