import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/pages/overall_results_page.dart';
import 'package:uritect_app/pages/results_page.dart';
import 'package:uritect_app/pages/symptom_checklist_page.dart';

ScanResult _scan() {
  DipstickResultRow row(String code, String name, String result) {
    return DipstickResultRow(
      code: code,
      name: name,
      result: result,
      referenceRange: 'Test reference',
      status: result == 'Neg'
          ? DipstickResultStatus.negative
          : DipstickResultStatus.moderate,
    );
  }

  return ScanResult(
    id: 'ui_test',
    date: DateTime(2026, 9, 26),
    imagePath: '',
    status: 'complete',
    confidence: 0.91,
    riskBucket: 'Complete',
    modelVersion: 'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
    rows: [
      row('LEU', 'Leukocytes', 'Moderate 125'),
      row('NIT', 'Nitrite', 'Positive'),
      row('URO', 'Urobilinogen', 'Normal'),
      row('PRO', 'Protein', 'Neg'),
      row('pH', 'pH', '6.0'),
      row('BLD', 'Blood', 'Neg'),
      row('SG', 'Specific Gravity', '1.015'),
      row('KET', 'Ketone', 'Neg'),
      row('BIL', 'Bilirubin', 'Neg'),
      row('GLU', 'Glucose', 'Neg'),
    ],
    padsDetected: 10,
    padsUnavailable: 0,
  );
}

ClinicalChecklistResult _eligibleChecklist() {
  const selected = {
    'uti_eligible_female',
    'uti_eligible_age_18_64',
    'uti_eligible_nonpregnant',
    'uti_eligible_no_catheter',
    'uti_eligible_no_urologic_abnormality',
    'uti_eligible_not_immunocompromised',
    'dysuria',
    'urgency',
  };
  return ClinicalChecklistResult(
    selectedSymptoms: {
      for (final item in clinicalSymptoms) item.id: selected.contains(item.id),
    },
  );
}

ClinicalChecklistResult _eligibleMaleChecklist() {
  const selected = {
    'uti_eligible_male',
    'uti_eligible_age_18_64',
    'uti_eligible_no_catheter',
    'uti_eligible_no_urologic_abnormality',
    'uti_eligible_not_immunocompromised',
    'uti_male_no_diabetes',
    'uti_male_no_suspected_sti',
    'dysuria',
  };
  return ClinicalChecklistResult(
    selectedSymptoms: {
      for (final item in clinicalSymptoms) item.id: selected.contains(item.id),
    },
  );
}

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('results display Bayesian percentage and applied factors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        OverallResultsPage(
          scanResult: _scan(),
          clinicalChecklistResult: _eligibleChecklist(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Female Bayesian UTI Research Estimate'), findsOneWidget);
    expect(find.text('91.5%'), findsOneWidget);
    expect(find.text('LR 7.20'), findsOneWidget);
    expect(find.text('LR 1.50'), findsOneWidget);
    expect(find.text('Consultation suggested'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/bayesian_results_phone.png'),
    );
  });

  testWidgets('checklist presents three focused workflow steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(SymptomChecklistPage(scanResult: _scan())));
    await tester.pumpAndSettle();

    expect(find.text('Bayesian UTI screening inputs'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Safety and renal follow-up'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Test context and reliability'), findsOneWidget);
    expect(find.textContaining('CALCULATE RESULTS'), findsOneWidget);
  });

  testWidgets('male pathway displays its separate model and one factor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        OverallResultsPage(
          scanResult: _scan(),
          clinicalChecklistResult: _eligibleMaleChecklist(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Male Bayesian UTI Research Estimate'), findsOneWidget);
    expect(find.text('LR 5.14'), findsOneWidget);
    expect(find.text('84.9%'), findsOneWidget);
    expect(find.text('Starting prior: 52.2%'), findsOneWidget);
    expect(find.textContaining('uti_bayesian_male_v0_1'), findsOneWidget);
  });

  testWidgets('scan results continue into the clinical checklist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(ResultsPage(scanResult: _scan())));
    await tester.pumpAndSettle();

    expect(find.text('CONTINUE TO CHECKLIST'), findsOneWidget);
    await tester.tap(find.text('CONTINUE TO CHECKLIST'));
    await tester.pumpAndSettle();
    expect(find.text('Bayesian UTI screening inputs'), findsOneWidget);
  });
  testWidgets(
    'history displays recorded posterior instead of recalculating it',
    (tester) async {
      await tester.pumpWidget(
        _app(
          OverallResultsPage(
            scanResult: _scan(),
            clinicalChecklistResult: _eligibleChecklist(),
            savedUtiEstimate: const BayesianUtiEstimate(
              modelVersion: ScreeningFusionEngine.femaleModelVersion,
              priorProbability: 0.5,
              posteriorProbability: 0.12,
              calculationStatus: 'calculated',
              statusReason: 'Synthetic saved record',
              factors: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12.0%'), findsOneWidget);
      expect(find.text('91.5%'), findsNothing);
      expect(
        find.textContaining('Saved research estimate shown as recorded'),
        findsOneWidget,
      );
    },
  );
}
