import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/models/saved_scan_record.dart';

ClinicalChecklistResult inputs({
  bool male = false,
  List<String> symptoms = const ['dysuria'],
  String? omit,
}) {
  final ids = <String>{
    male ? 'uti_eligible_male' : 'uti_eligible_female',
    ...male
        ? ScreeningFusionEngine.maleEligibilityConfirmations
        : ScreeningFusionEngine.femaleEligibilityConfirmations,
    ...symptoms,
  }..remove(omit);
  return ClinicalChecklistResult(
    selectedSymptoms: {for (final id in ids) id: true},
  );
}

List<ScreeningAnalyteResult> evidence({
  String le = 'Neg',
  String nit = 'Neg',
  String blood = 'Neg',
  bool reliable = true,
}) => [
  ScreeningAnalyteResult(
    code: 'LEU',
    name: 'Leukocytes',
    displayValue: le,
    isReliable: reliable,
  ),
  ScreeningAnalyteResult(
    code: 'NIT',
    name: 'Nitrite',
    displayValue: nit,
    isReliable: reliable,
  ),
  ScreeningAnalyteResult(
    code: 'BLD',
    name: 'Blood',
    displayValue: blood,
    isReliable: reliable,
  ),
];
ScanResult scan() => ScanResult(
  id: 'audit',
  date: DateTime(2026, 10, 3),
  imagePath: '',
  status: 'complete',
  confidence: 0.9,
  riskBucket: 'Complete',
  modelVersion: 'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
  padsDetected: 10,
  padsUnavailable: 0,
  rows: sampleDipstickRows
      .map(
        (row) => DipstickResultRow(
          code: row.code,
          name: row.name,
          result: row.code == 'NIT' ? 'Positive' : 'Neg',
          referenceRange: '',
          status: DipstickResultStatus.negative,
        ),
      )
      .toList(),
);
void main() {
  const engine = ScreeningFusionEngine();
  test('female Trace 15 cannot contribute to the all-negative rule', () {
    final result = engine.fuse(
      analytes: evidence(le: 'Trace 15'),
      checklist: inputs(symptoms: ['suprapubic']),
    );
    expect(result.utiEstimate.calculationStatus, 'insufficient');
    expect(result.utiEstimate.factors, isEmpty);
    final withSymptom = engine.fuse(
      analytes: evidence(le: 'Trace 15'),
      checklist: inputs(),
    );
    expect(withSymptom.utiEstimate.factors.map((f) => f.likelihoodRatio), [
      1.3,
    ]);
    final withNitrite = engine.fuse(
      analytes: evidence(le: 'Trace 15', nit: 'Positive'),
      checklist: inputs(symptoms: ['suprapubic']),
    );
    expect(withNitrite.utiEstimate.factors.single.likelihoodRatio, 5.5);
  });
  test('male ordered hierarchy selects one unchanged LR and male prior', () {
    final cases = [
      (le: 'Trace 15', nit: 'Positive', lr: 5.14),
      (le: 'Neg', nit: 'Positive', lr: 4.87),
      (le: 'Trace 15', nit: 'Neg', lr: 1.65),
      (le: 'Neg', nit: 'Neg', lr: 0.35),
    ];
    for (final item in cases) {
      final result = engine.fuse(
        analytes: evidence(le: item.le, nit: item.nit, blood: 'Large 200'),
        checklist: inputs(
          male: true,
          symptoms: ['dysuria', 'urgency', 'frequency'],
        ),
      );
      expect(result.utiEstimate.factors, hasLength(1));
      expect(result.utiEstimate.factors.single.likelihoodRatio, item.lr);
      expect(result.utiEstimate.priorProbability, 97 / 186);
      expect(
        result.utiEstimate.modelVersion,
        ScreeningFusionEngine.maleModelVersion,
      );
    }
  });
  test('female overlapping findings select at most one factor per group', () {
    final result = engine.fuse(
      analytes: evidence(le: 'Large 500', nit: 'Positive', blood: 'Large 200'),
      checklist: inputs(
        symptoms: ['dysuria', 'urgency', 'frequency', 'hematuria'],
      ),
    );
    expect(result.utiEstimate.factors.map((f) => f.likelihoodRatio), [
      7.2,
      1.5,
    ]);
    expect(result.utiEstimate.priorProbability, 0.5);
  });
  test(
    'missing unknown unavailable and unreliable are not negative evidence',
    () {
      for (final value in ['', 'Unknown', 'Unavailable', 'Unreliable']) {
        final result = engine.fuse(
          analytes: evidence(le: value, nit: value, blood: value),
          checklist: inputs(symptoms: ['suprapubic']),
        );
        expect(result.utiEstimate.factors, isEmpty);
        final male = engine.fuse(
          analytes: evidence(le: value, nit: value),
          checklist: inputs(male: true),
        );
        expect(male.utiEstimate.calculationStatus, 'insufficient');
        expect(male.utiEstimate.factors, isEmpty);
      }
      final missing = engine.fuse(
        analytes: [],
        checklist: inputs(symptoms: ['suprapubic']),
      );
      expect(missing.utiEstimate.factors, isEmpty);
      for (final male in [false, true]) {
        final result = engine.fuse(
          analytes: evidence(nit: 'Positive', reliable: false),
          checklist: inputs(
            male: male,
            symptoms: male ? ['urgency'] : ['suprapubic'],
          ),
        );
        expect(result.utiEstimate.factors, isEmpty);
      }
    },
  );
  test(
    'every unconfirmed sex-specific eligibility requirement blocks calculation',
    () {
      for (final male in [false, true]) {
        final requiredIds = male
            ? ScreeningFusionEngine.maleEligibilityConfirmations
            : ScreeningFusionEngine.femaleEligibilityConfirmations;
        for (final id in requiredIds) {
          final result = engine.fuse(
            analytes: evidence(nit: 'Positive'),
            checklist: inputs(male: male, omit: id),
          );
          expect(
            result.utiEstimate.calculationStatus,
            'not_designed',
            reason: id,
          );
          expect(result.utiEstimate.factors, isEmpty);
        }
      }
    },
  );
  test(
    'serious systemic flags block the ordinary posterior for either sex',
    () {
      for (final male in [false, true]) {
        for (final flag in [
          'fever',
          'flank',
          'nausea',
          'cannot_hydrate_or_medicate',
          'confusion_fainting_weakness',
        ]) {
          final result = engine.fuse(
            analytes: evidence(),
            checklist: inputs(male: male, symptoms: ['dysuria', flag]),
          );
          expect(result.utiEstimate.isCalculable, isFalse, reason: flag);
          expect(result.utiEstimate.factors, isEmpty);
          expect(result.clinicalAction.toLowerCase(), contains('consultation'));
        }
      }
    },
  );
  test(
    'renal safety overrides stop ordinary estimates without modifying renal rules',
    () {
      for (final male in [false, true]) {
        final result = engine.fuse(
          analytes: evidence(),
          scanResult: scan(),
          checklist: inputs(
            male: male,
            symptoms: ['dysuria', 'reduced_urine_output'],
          ),
        );
        expect(result.utiEstimate.calculationStatus, 'not_designed');
        expect(result.utiEstimate.factors, isEmpty);
      }
    },
  );
  test(
    'invalid or low-confidence scans cannot produce symptom-only posteriors',
    () {
      final base = scan();
      final confidences = {for (final row in base.rows) row.name: 0.9};
      final cases = [
        base.copyWith(status: 'invalid'),
        base.copyWith(confidence: 0.44),
        base.copyWith(confidence: double.nan),
        base.copyWith(padsDetected: 9),
        base.copyWith(analyteConfidences: {...confidences, 'Leukocytes': 0.44}),
        base.copyWith(analyteConfidences: {'Leukocytes': 0.9}),
      ];
      for (final item in cases) {
        final result = engine.fuse(
          analytes: evidence(nit: 'Positive'),
          scanResult: item,
          checklist: inputs(),
        );
        expect(result.utiEstimate.calculationStatus, 'insufficient');
        expect(result.utiEstimate.factors, isEmpty);
        final renal = const RenalFollowupEngine().evaluate(
          scanResult: item,
          checklist: inputs(),
        );
        expect(renal.finalAction, RenalAction.retake);
        expect(renal.proteinReliable, isFalse);
        expect(renal.bloodReliable, isFalse);
      }
      expect(
        base
            .copyWith(
              confidence: 0.45,
              analyteConfidences: {for (final row in base.rows) row.name: 0.45},
            )
            .isReliableForInterpretation,
        isTrue,
      );
    },
  );
  test(
    'test-quality failures block updates but do not suppress safety advice',
    () {
      for (final flag in [
        'strip_expired',
        'strip_damaged',
        'read_outside_60_seconds',
        'unsupported_strip',
      ]) {
        final result = engine.fuse(
          analytes: evidence(nit: 'Positive'),
          scanResult: scan(),
          checklist: inputs(symptoms: ['dysuria', flag]),
        );
        expect(result.utiEstimate.calculationStatus, 'insufficient');
        final safety = engine.fuse(
          analytes: [],
          scanResult: scan().copyWith(status: 'invalid'),
          checklist: inputs(symptoms: ['dysuria', 'fever', 'flank', flag]),
        );
        expect(safety.clinicalAction, 'Prompt medical consultation suggested');
      }
    },
  );
  test('invalid test quality never interprets protein or blood categories', () {
    final base = scan();
    final positive = base.copyWith(
      rows: base.rows
          .map(
            (row) => DipstickResultRow(
              code: row.code,
              name: row.name,
              result: row.code == 'PRO'
                  ? '0.3'
                  : row.code == 'BLD'
                  ? 'Large 200'
                  : row.result,
              referenceRange: '',
              status: row.status,
            ),
          )
          .toList(),
    );
    final result = const RenalFollowupEngine().evaluate(
      scanResult: positive,
      checklist: inputs(symptoms: ['strip_expired']),
    );
    expect(result.proteinReliable, isFalse);
    expect(result.bloodReliable, isFalse);
    expect(result.finalAction, RenalAction.retake);
    expect(result.triggeredRules.map((r) => r.id), isNot(contains('COMB-01')));
  });

  test(
    'audit JSON preserves sex-specific model prior factors status and confidence',
    () {
      for (final male in [false, true]) {
        final base = scan();
        final input = base.copyWith(
          analyteConfidences: {for (final row in base.rows) row.name: 0.9},
        );
        final flags = inputs(male: male);
        final fusion = engine.fuse(
          analytes: evidence(nit: 'Positive'),
          scanResult: input,
          checklist: flags,
        );
        final renal = const RenalFollowupEngine().evaluate(
          scanResult: input,
          checklist: flags,
        );
        final record = SavedScanRecord.fromAnalysis(
          scanResult: input,
          checklistResult: flags,
          fusionResult: fusion,
          renalFollowupResult: renal,
        );
        final restored = SavedScanRecord.fromJson(record.toJson());
        expect(restored.bayesianModelVersion, fusion.utiEstimate.modelVersion);
        expect(
          restored.utiPriorProbability,
          fusion.utiEstimate.priorProbability,
        );
        expect(
          restored.utiPosteriorProbability,
          fusion.utiEstimate.posteriorProbability,
        );
        expect(
          restored.utiEvidenceFactors.map((f) => f.likelihoodRatio),
          fusion.utiEstimate.factors.map((f) => f.likelihoodRatio),
        );
        expect(restored.utiCalculationStatus, 'calculated');
        expect(
          restored.interpretationPolicyVersion,
          ScreeningFusionEngine.interpretationPolicyVersion,
        );
        expect(
          restored.scanResult.analyteConfidences,
          input.analyteConfidences,
        );
      }
    },
  );
}
