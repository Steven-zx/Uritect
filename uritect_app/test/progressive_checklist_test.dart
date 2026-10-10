import 'verified_scan_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/checklist_draft.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/pages/symptom_checklist_page.dart';

ScanResult scan() => verifiedFixture(
  ScanResult(
    id: 'progressive',
    date: DateTime(2026, 10, 5),
    imagePath: '',
    status: 'complete',
    confidence: .9,
    riskBucket: 'Complete',
    modelVersion: 'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
    rows: [
      for (final pair in [
        ['LEU', 'Leukocytes', 'Moderate 125'],
        ['NIT', 'Nitrite', 'Positive'],
        ['PRO', 'Protein', 'Neg'],
        ['BLD', 'Blood', 'Neg'],
        ['URO', 'Urobilinogen', 'Normal'],
        ['pH', 'pH', '6.0'],
        ['SG', 'Specific Gravity', '1.015'],
        ['KET', 'Ketone', 'Neg'],
        ['BIL', 'Bilirubin', 'Neg'],
        ['GLU', 'Glucose', 'Neg'],
      ])
        DipstickResultRow(
          code: pair[0],
          name: pair[1],
          result: pair[2],
          referenceRange: '',
          status: DipstickResultStatus.negative,
        ),
    ],
  ),
);

ChecklistDraft eligible() {
  final d = ChecklistDraft()..sex('female');
  for (final id in ScreeningFusionEngine.femaleEligibilityConfirmations) {
    d.answer(id, 'yes');
  }
  for (final id in [
    'frequency',
    'urgency',
    'suprapubic',
    'vaginal_discharge',
    'vaginal_irritation',
  ]) {
    d.answer(id, 'no');
  }
  d.answer('dysuria', 'yes');
  d.answer('safety_review', 'no');
  d.answer('quality_review', 'no');
  return d;
}

void main() {
  testWidgets(
    'negative renal pads hide details; uncertain quality reveals checks',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SymptomChecklistPage(scanResult: scan())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('age_band')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18–64').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sex_male')));
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      for (final id in [
        'dysuria',
        'frequency',
        'urgency',
        'suprapubic',
        'uti_eligible_no_catheter',
        'uti_eligible_no_urologic_abnormality',
        'uti_eligible_not_immunocompromised',
        'uti_male_no_diabetes',
        'uti_male_no_suspected_sti',
      ]) {
        final answer = find.byKey(ValueKey('$id:no'));
        await tester.ensureVisible(answer);
        await tester.tap(answer);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('safety_review:no')));
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('renal_history:no')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('question_repeat_protein_present')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('question_repeat_blood_present')),
        findsNothing,
      );
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('question_strip_expired')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('quality_review:unsure')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('question_strip_expired')),
        findsOneWidget,
      );
      expect(find.text('VIEW RESULTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('explicit answers survive JSON without inventing negative answers', () {
    final d = ChecklistDraft()..sex('female');
    d.answer('dysuria', 'unsure');
    d.answer('frequency', 'no');
    final r = ClinicalChecklistResult.fromJson(d.result().toJson());
    expect(r.answers['dysuria'], 'unsure');
    expect(r.responseLabel('frequency'), 'No');
    expect(r.responseLabel('urgency'), 'Not asked / unanswered');
    expect(r.selectedSymptoms['dysuria'], isFalse);
    expect(r.hasIncompleteSafetyReview, isTrue);
  });
  test('sex switch clears hidden confirmations and female context', () {
    final d = eligible();
    d.answer('menstruation_or_vaginal_bleeding', 'yes');
    d.sex('male');
    expect(d.result().selectedSymptoms['uti_eligible_nonpregnant'], isFalse);
    expect(d.answers.containsKey('menstruation_or_vaginal_bleeding'), isFalse);
    d.answer('uti_male_no_diabetes', 'yes');
    d.sex('female');
    expect(d.answers.containsKey('uti_male_no_diabetes'), isFalse);
  });
  test('group No is explicit; expanding does not retain inferred No', () {
    final d = eligible();
    expect(checklistSafetyIds.every((id) => d.answers[id] == 'no'), isTrue);
    d.answer('safety_review', 'yes');
    expect(
      checklistSafetyIds.every((id) => !d.answers.containsKey(id)),
      isTrue,
    );
    d.answer('fever', 'yes');
    d.answer('safety_review', 'yes');
    expect(d.answers['fever'], 'yes');
  });
  test(
    'current candidate parameters retained; unknown inputs block posterior',
    () {
      BayesianUtiEstimate estimate(ChecklistDraft d) =>
          const ScreeningFusionEngine()
              .fuse(
                scanResult: scan(),
                analytes: ScreeningFusionEngine.buildAnalytesFromRows(
                  scan().rows,
                ),
                checklist: d.result(),
              )
              .utiEstimate;
      final d = eligible();
      final baseline = estimate(d);
      expect(baseline.calculationStatus, 'calculated');
      expect(baseline.factors.first.likelihoodRatio, 7.2);
      expect(baseline.factors.last.likelihoodRatio, 1.3);
      d.answer('urgency', 'unsure');
      expect(estimate(d).calculationStatus, 'insufficient');
      d.answer('urgency', 'no');
      d.answer('safety_review', 'unsure');
      expect(estimate(d).calculationStatus, 'insufficient');
      d.answer('safety_review', 'no');
      d.answer('quality_review', 'unsure');
      expect(estimate(d).calculationStatus, 'insufficient');
      final renal = const RenalFollowupEngine().evaluate(
        scanResult: scan(),
        checklist: d.result(),
      );
      expect(renal.finalAction, RenalAction.retake);
      expect(renal.proteinReliable, isFalse);
    },
  );
  test('known serious symptoms retain prompt safety despite uncertainty', () {
    final d = eligible();
    d.answer('safety_review', 'yes');
    d.answer('reduced_urine_output', 'yes');
    d.answer('quality_review', 'unsure');
    expect(
      const RenalFollowupEngine()
          .evaluate(scanResult: scan(), checklist: d.result())
          .finalAction,
      RenalAction.promptConsult,
    );
  });
  testWidgets('male branch hides pregnancy and menstruation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SymptomChecklistPage(scanResult: scan())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('age_band')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18–64').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sex_male')));
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Male pathway'), findsOneWidget);
    expect(find.text('Are you currently pregnant?'), findsNothing);
    expect(
      find.byKey(const ValueKey('question_menstruation_or_vaginal_bleeding')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('question_uti_male_no_diabetes')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
