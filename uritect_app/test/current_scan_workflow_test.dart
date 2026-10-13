import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/config/theme.dart';
import 'package:uritect_app/models/checklist_draft.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/pages/overall_results_page.dart';
import 'package:uritect_app/pages/symptom_checklist_page.dart';
import 'package:uritect_app/pages/results_page.dart';
import 'package:uritect_app/services/scan_history_service.dart';
import 'package:uritect_app/services/history_cipher.dart';
import 'package:uritect_app/services/pending_scan_cipher.dart';
import 'package:uritect_app/widgets/dipstick_results_table.dart';
import 'package:uritect_app/widgets/dataset_level_legend.dart';
import 'provisional_readings_test.dart' as fixture;

class QueueSpy extends ScanHistoryService {
  final List<ClinicalChecklistResult> saved = [];
  final List<ScanResult> scans = [];
  @override
  Future<void> queueCompletedScan({
    required ScanResult scanResult,
    required ClinicalChecklistResult checklistResult,
    required ScreeningFusionResult fusionResult,
    required RenalFollowupResult renalFollowupResult,
  }) async {
    scans.add(scanResult);
    saved.add(checklistResult);
  }

  @override
  Future<void> authenticate() async {
    throw StateError('Current scan tried to authenticate');
  }
}

ClinicalChecklistResult answers() {
  final d = ChecklistDraft()..sex('male');
  d.answers.addAll({
    'age_band': '18_64',
    'uti_eligible_age_18_64': 'yes',
    'dysuria': 'no',
    'frequency': 'no',
    'urgency': 'no',
    'suprapubic': 'no',
    'uti_eligible_no_catheter': 'yes',
    'uti_eligible_no_urologic_abnormality': 'yes',
    'uti_eligible_not_immunocompromised': 'yes',
    'uti_male_no_diabetes': 'yes',
    'uti_male_no_suspected_sti': 'yes',
    'safety_review': 'no',
    'renal_history': 'no',
    'quality_review': 'no',
  });
  d.answer('safety_review', 'no');
  d.answer('quality_review', 'no');
  return d.result();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('platform pending sealing never invokes authentication', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformHistoryCipher.channel, (call) async {
          calls.add(call.method);
          return Uint8List.fromList([1]);
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformHistoryCipher.channel, null),
    );
    await const PlatformPendingScanCipher().seal(
      Uint8List.fromList([2]),
      'uritect:pending:${'a' * 64}',
      false,
    );
    expect(calls, ['sealPending']);
  });
  testWidgets(
    'edit restores answers, recalculates summary and reuses original scan without authentication',
    (tester) async {
      final service = QueueSpy();
      final scan = fixture.baseScan();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OverallResultsPage(
            scanResult: scan,
            clinicalChecklistResult: answers(),
            historyService: service,
          ),
        ),
      );
      await tester.tap(find.text('Edit Checklist'));
      await tester.pumpAndSettle();
      final page = tester.widget<SymptomChecklistPage>(
        find.byType(SymptomChecklistPage),
      );
      expect(page.initialChecklistResult!.answers, answers().answers);
      expect(page.scanResult, same(scan));
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('dysuria:yes')));
      await tester.tap(find.byKey(const ValueKey('dysuria:yes')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('VIEW RESULTS'));
      await tester.pumpAndSettle();
      expect(service.saved.length, 1);
      expect(service.saved.single.answers['dysuria'], 'yes');
      expect(service.scans.single, same(scan));
      final summary = tester.widget<OverallResultsPage>(
        find.byType(OverallResultsPage),
      );
      expect(summary.clinicalChecklistResult.answers['dysuria'], 'yes');
      expect(summary.scanResult.id, scan.id);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'simplified results retain predictions without status labels and never invent missing readings',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultsPage(
            scanResult: fixture.baseScan().copyWith(status: 'invalid'),
          ),
        ),
      );
      expect(find.text('6.5'), findsOneWidget);
      expect(
        find.textContaining('Preliminary model predictions'),
        findsNothing,
      );
      expect(find.text('Unverified'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: ResultsPage(
            scanResult: fixture.baseScan().copyWith(
              status: 'invalid',
              rows: [],
            ),
          ),
        ),
      );
      expect(find.byType(DipstickResultsTable), findsNothing);
      expect(find.text('6.5'), findsNothing);
    },
  );
  testWidgets(
    'timing labels leave predicted values visible without relaxing clinical gates',
    (tester) async {
      final scan = fixture.baseScan();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DipstickResultsTable(
                rows: scan.rows,
                analyteConfidences: scan.analyteConfidences,
                scanVerified: true,
                secondsAfterDipping: 60,
              ),
            ),
          ),
        ),
      );
      expect(find.text('1.015'), findsOneWidget);
      expect(find.text('Provisional'), findsNWidgets(4));
      expect(scan.hasMatchingReportedReadingTime('SG'), false);
    },
  );
  testWidgets('small phone large text retains visible teal summary actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: OverallResultsPage(
            scanResult: fixture.baseScan(),
            clinicalChecklistResult: answers(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit Checklist'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(
      AppTheme.lightTheme.outlinedButtonTheme.style!.side!.resolve({})!.color,
      AppColors.primaryMain,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reference legend contains labels and explicitly excludes unverified color swatches',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DatasetLevelLegend()),
          ),
        ),
      );
      await tester.tap(find.text('Dataset level reference'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not a verified strip color chart'),
        findsOneWidget,
      );
      expect(DatasetLevelLegend.levels['pH'], contains('6.5'));
    },
  );
}
