import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/pages/results_page.dart';
import 'verified_scan_fixture.dart';

ScanResult baseScan() => verifiedFixture(
  ScanResult(
    id: 'provisional',
    date: DateTime(2026, 10, 11),
    imagePath: '',
    status: 'complete',
    confidence: .9,
    riskBucket: 'Complete',
    modelVersion: 'test',
    rows: [
      for (final e in ScanResult.expectedAnalytes.entries)
        DipstickResultRow(
          code: e.key,
          name: e.value,
          result:
              {
                'LEU': 'Moderate 125',
                'NIT': 'Positive',
                'URO': '3.2',
                'pH': '6.5',
                'SG': '1.015',
              }[e.key] ??
              'Neg',
          referenceRange: '',
          status: DipstickResultStatus.negative,
        ),
    ],
  ),
).copyWith(modelVersion: 'direction_verified_experimental_v1_20261011');
ClinicalChecklistResult checklist() {
  final yes = {
    'uti_eligible_female',
    ...ScreeningFusionEngine.femaleEligibilityConfirmations,
    'dysuria',
  };
  return ClinicalChecklistResult(
    selectedSymptoms: {
      for (final s in clinicalSymptoms) s.id: yes.contains(s.id),
    },
  );
}

ScanResult weak(String name) {
  final s = baseScan();
  return s.copyWith(
    status: 'review_required',
    rejectionCode: 'LOW_CONFIDENCE',
    analyteConfidences: {...s.analyteConfidences, name: .2},
  );
}

BayesianUtiEstimate estimate(ScanResult s) => const ScreeningFusionEngine()
    .fuse(
      scanResult: s,
      analytes: ScreeningFusionEngine.buildAnalytesFromRows(s.rows),
      checklist: checklist(),
    )
    .utiEstimate;
RenalFollowupResult renal(ScanResult s) =>
    const RenalFollowupEngine().evaluate(scanResult: s, checklist: checklist());
void main() {
  test(
    'weak pH retains ten numeric readings without changing Bayesian inputs',
    () {
      final s = ScanResult.fromJson(weak('pH').toJson());
      expect(s.rows.length, 10);
      expect(s.isReliableForInterpretation, false);
      expect(estimate(s).isCalculable, true);
      expect(
        estimate(s).posteriorProbability,
        estimate(baseScan()).posteriorProbability,
      );
      expect(renal(s).scanValid, true);
    },
  );
  test('weak LEU blocks Bayesian but leaves adequate renal inputs usable', () {
    expect(estimate(weak('Leukocytes')).isCalculable, false);
    expect(renal(weak('Leukocytes')).scanValid, true);
  });
  test(
    'weak protein blocks renal but does not contaminate Bayesian inputs',
    () {
      expect(renal(weak('Protein')).scanValid, false);
      expect(estimate(weak('Protein')).isCalculable, true);
    },
  );
  test('weak blood blocks both dependent calculations', () {
    expect(renal(weak('Blood')).scanValid, false);
    expect(estimate(weak('Blood')).isCalculable, false);
  });
  test(
    'partial reporting cannot bypass missing metadata or specimen context',
    () {
      final s = weak('pH');
      for (final bad in [
        s.copyWith(supportCheckPassed: false),
        s.copyWith(stripDirectionVerified: false),
        s.copyWith(analyteConfidences: {}),
        s.copyWith(confidence: double.nan),
        s.copyWith(
          modelVersion:
              'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
        ),
      ]) {
        expect(estimate(bad).isCalculable, false);
        expect(renal(bad).scanValid, false);
      }
      final json = s.toJson()..remove('provenance');
      expect(estimate(ScanResult.fromJson(json)).isCalculable, false);
    },
  );
  testWidgets('results show the pH value and visible provisional confidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ResultsPage(scanResult: weak('pH'))),
    );
    expect(find.text('6.5'), findsNothing);
    expect(find.text('Uncertain'), findsWidgets);
    await tester.ensureVisible(find.text('pH'));
    await tester.tap(find.text('pH'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    expect(find.textContaining('Vote confidence'), findsNothing);
    await tester.ensureVisible(find.text('Research Details'));
    await tester.tap(find.text('Research Details'));
    await tester.pumpAndSettle();
    expect(find.text('pH: 6.5'), findsOneWidget);
    expect(find.text('Vote confidence: 20%'), findsOneWidget);
    expect(find.text('CONTINUE TO CHECKLIST'), findsOneWidget);
  });
}
