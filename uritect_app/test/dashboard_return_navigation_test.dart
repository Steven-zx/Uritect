import 'package:flutter/material.dart';
import 'package:uritect_app/models/scan_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/pages/analyzing_page.dart';
import 'package:uritect_app/pages/overall_results_page.dart';
import 'package:uritect_app/pages/results_page.dart';
import 'package:uritect_app/pages/root_page.dart';
import 'package:uritect_app/pages/symptom_checklist_page.dart';
import 'package:uritect_app/services/scan_analysis_service.dart';
import 'package:uritect_app/widgets/dipstick_results_table.dart';

class InvalidAnalysis extends ScanAnalysisService {
  const InvalidAnalysis();
  @override
  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double, String)? onProgress,
    void Function(ScanLocalization)? onLocalization,
  }) async {
    throw StateError('INVALID_IMAGE: no strip');
  }
}

void main() {
  for (final fromOverall in [false, true]) {
    testWidgets(
      'Home from ${fromOverall ? 'overall' : 'dipstick'} results cannot over-pop dashboard',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const RootPage()),
        );
        // Simulate the actual capture -> analysis -> results stack. Analysis is
        // genuinely awaiting results when Home removes these routes.
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Capture placeholder')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const AnalyzingPage(
              imagePath: 'synthetic.png',
              analysisService: InvalidAnalysis(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ResultsPage), findsOneWidget);
        if (fromOverall) {
          await tester.tap(find.text('COMPLETE SAFETY CHECKLIST'));
          await tester.pumpAndSettle();
          expect(find.byType(SymptomChecklistPage), findsOneWidget);
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => OverallResultsPage(
                scanResult: ScanResult.empty(
                  imagePath: '',
                ).copyWith(status: 'invalid'),
                clinicalChecklistResult: ClinicalChecklistResult(
                  selectedSymptoms: const {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('HOME'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(RootPage), findsOneWidget);
        expect(find.text('START SCAN'), findsOneWidget);
        expect(find.byType(AnalyzingPage), findsNothing);
        expect(find.byType(ResultsPage), findsNothing);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final prompt in [false, true]) {
    testWidgets(
      'safety warning stays visible without opening details: prompt=$prompt',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: OverallResultsPage(
              scanResult: ScanResult.empty(
                imagePath: '',
              ).copyWith(status: 'invalid'),
              clinicalChecklistResult: ClinicalChecklistResult(
                selectedSymptoms: {'fever': true, if (prompt) 'flank': true},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            prompt
                ? 'Prompt medical consultation suggested'
                : 'Systemic symptom requires consultation',
          ),
          findsWidgets,
        );
        expect(
          find.textContaining(
            prompt
                ? 'This combination may indicate serious illness'
                : 'This finding is outside the ordinary lower-UTI estimate',
          ),
          findsOneWidget,
        );
        expect(find.text('Why this guidance was shown'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'long strip reading remains readable on small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const value = 'Moderate 125 cells/uL';
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DipstickResultsTable(
                  scanVerified: true,
                  analyteConfidences: {'Leukocytes': .91},
                  secondsAfterDipping: 60,
                  rows: [
                    DipstickResultRow(
                      code: 'LEU',
                      name: 'Leukocytes',
                      result: value,
                      referenceRange: 'Negative',
                      status: DipstickResultStatus.moderate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(value));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(find.text('Negative'), findsNothing);
      await tester.tap(find.text('Leukocytes'));
      await tester.pumpAndSettle();
      expect(find.text('Result: $value'), findsOneWidget);
      expect(find.text('Reference: Negative'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
