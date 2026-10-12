import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/scan_provenance.dart';
import 'verified_scan_fixture.dart';

ScanResult scan() => verifiedFixture(
  ScanResult(
    id: 'test',
    date: DateTime(2026, 10, 10),
    imagePath: '',
    status: 'complete',
    confidence: .9,
    riskBucket: 'Complete',
    modelVersion: 'test',
    rows: [
      for (final item in ScanResult.expectedAnalytes.entries)
        DipstickResultRow(
          code: item.key,
          name: item.value,
          result: 'Neg',
          referenceRange: '',
          status: DipstickResultStatus.negative,
        ),
    ],
  ),
);
void main() {
  test(
    'old production records remain preserved but cannot support interpretation',
    () {
      final old = scan().copyWith(
        modelVersion:
            'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
      );
      final loaded = ScanResult.fromJson(old.toJson());
      expect(loaded.rows.length, 10);
      expect(loaded.hasQuarantinedOrientationModel, true);
      expect(loaded.isReliableForInterpretation, false);
      expect(loaded.isUsableForCurrentInterpretation, false);
    },
  );
  test('only complete exact unique analytes with all safety evidence pass', () {
    final good = scan();
    expect(good.isReliableForInterpretation, isTrue);
    expect(good.isUsableForCurrentInterpretation, isFalse);
    expect(
      good.hasUsableAnalytesForCurrentInterpretation({'LEU', 'NIT', 'BLD'}),
      isTrue,
    );
    for (final bad in [
      good.copyWith(analyteConfidences: {}),
      good.copyWith(padsDetected: 9),
      good.copyWith(padsUnavailable: 1),
      good.copyWith(rows: [...good.rows.take(9), good.rows.first]),
      good.copyWith(stripDirectionVerified: false),
      good.copyWith(modelDirectionReviewed: false),
      good.copyWith(supportCheckPassed: false),
      good.copyWith(nearestTrainingDistances: {}),
      good.copyWith(confidence: double.nan),
      good.copyWith(
        analyteConfidences: {...good.analyteConfidences, 'Glucose': .44},
      ),
      good.copyWith(
        analyteConfidences: {
          ...good.analyteConfidences,
          'Glucose': double.infinity,
        },
      ),
      good.copyWith(
        nearestTrainingDistances: {
          ...good.nearestTrainingDistances,
          'Glucose': -1,
        },
      ),
    ]) {
      expect(bad.isReliableForInterpretation, isFalse);
    }
    final malformed = good.toJson()..['padsDetected'] = 10.7;
    expect(ScanResult.fromJson(malformed).isReliableForInterpretation, isFalse);
    final legacy = good.toJson()
      ..remove('analyteConfidences')
      ..remove('supportCheckPassed')
      ..remove('nearestTrainingDistances')
      ..remove('provenance');
    final archived = ScanResult.fromJson(legacy);
    expect(archived.isLegacyUnverified, isTrue);
    expect(archived.isUsableForCurrentInterpretation, isFalse);
  });
  test(
    'current context needs provenance; old and exact duplicate photos cannot become current',
    () {
      final base = scan().provenance!.toJson();
      for (final change in [
        {'source': 'unknown'},
        {'duplicateCheckCompleted': false},
        {'currentSpecimenConfirmed': false},
        {'specimenCode': ''},
        {'secondsAfterDipping': null},
        {'secondsAfterDipping': -1},
        {'duplicateOf': 'old'},
        {'reportedPhotoDate': '2026-10-09T12:00:00'},
        {'contentSha256': ''},
        {'capturedAt': null},
      ]) {
        final p = ScanProvenance.fromJson({...base, ...change});
        expect(p.canSupportCurrentContext, isFalse, reason: change.toString());
        expect(
          scan().copyWith(provenance: p).isUsableForCurrentInterpretation,
          isFalse,
        );
      }
      final similar = ScanProvenance.fromJson({
        ...base,
        'similarImageOf': 'old',
      });
      expect(
        similar.canSupportCurrentContext,
        isTrue,
        reason: 'Perceptual similarity alone does not prove reuse.',
      );
      final imported = ScanProvenance.fromJson({
        ...base,
        'source': 'import',
        'capturedAt': null,
      });
      expect(imported.canSupportCurrentContext, isTrue);
      expect(
        ScanProvenance.fromJson(imported.toJson()).toJson(),
        imported.toJson(),
      );
    },
  );
}
