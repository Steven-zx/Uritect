import 'verified_scan_fixture.dart';
import 'support/load_app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uritect_app/config/theme.dart';
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

  return verifiedFixture(
    ScanResult(
      id: 'ui_test',
      date: DateTime(2026, 9, 26),
      imagePath: '',
      status: 'complete',
      confidence: 0.91,
      riskBucket: 'Complete',
      modelVersion:
          'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
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
    ),
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

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await loadAppFonts();
  });
  testWidgets('screening summary retains guidance without research details', (
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
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();

    expect(find.text('UTI-related screening'), findsOneWidget);
    expect(find.text('91.5%'), findsNothing);
    expect(find.textContaining('LR 7.20'), findsNothing);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/bayesian_results_phone.png'),
    );
    expect(find.text('Research Details'), findsNothing);
    expect(find.text('Unable to complete screening'), findsNothing);
    expect(find.text('Consultation suggested'), findsOneWidget);
  });

  testWidgets('checklist begins with age and sex before pathway questions', (
    tester,
  ) async {
    await tester.pumpWidget(_app(SymptomChecklistPage(scanResult: _scan())));
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.text('Basic information'), findsWidgets);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Are you currently pregnant?'), findsNothing);
    await tester.tap(find.text('NEXT'));
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.textContaining('Answer each question'), findsOneWidget);
  });

  testWidgets('male summary omits technical model details', (tester) async {
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
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();

    expect(find.text('UTI-related screening'), findsOneWidget);
    expect(find.text('84.9%'), findsNothing);
    expect(find.textContaining('LR 5.14'), findsNothing);
    expect(find.text('Research Details'), findsNothing);
    expect(find.text('Starting prior: 52.2%'), findsNothing);
    expect(find.textContaining('uti_bayesian_male_v0_1'), findsNothing);
  });

  testWidgets('scan results continue into the clinical checklist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(ResultsPage(scanResult: _scan())));
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/dipstick_readings_phone.png'),
    );
    expect(find.text('CONTINUE TO CHECKLIST'), findsOneWidget);
    await tester.tap(find.text('CONTINUE TO CHECKLIST'));
    await tester.runAsync(() async => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.text('Basic information'), findsWidgets);
  });
  testWidgets(
    'summary preserves saved posterior without displaying research details',
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
      await tester.runAsync(() async => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(find.text('12.0%'), findsNothing);
      expect(find.text('Research Details'), findsNothing);
      expect(
        tester
            .widget<OverallResultsPage>(find.byType(OverallResultsPage))
            .savedUtiEstimate!
            .posteriorProbability,
        0.12,
      );
      expect(find.text('91.5%'), findsNothing);
      expect(
        find.textContaining(
          'Saved record. Follow-up guidance uses current rules.',
        ),
        findsOneWidget,
      );
    },
  );
}
