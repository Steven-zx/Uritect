import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/config/theme.dart';
import 'package:uritect_app/models/scan_provenance.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/pages/renal_results_page.dart';
import 'package:uritect_app/pages/about_page.dart';
import 'package:uritect_app/pages/overall_results_page.dart';
import 'package:uritect_app/services/scan_provenance_service.dart';
import 'package:uritect_app/widgets/scan_provenance_dialog.dart';
import 'provisional_readings_test.dart' as fixture;
import 'support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> openPhoto(
    WidgetTester tester,
    ValueChanged<ScanProvenance?> finish, {
    String? duplicate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async => finish(
                await showDialog<ScanProvenance>(
                  context: context,
                  builder: (_) => ScanProvenanceDialog(
                    identity: ImageIdentity('a' * 64, 'b' * 64, 'c' * 16, null),
                    source: 'import',
                    duplicateCheckCompleted: true,
                    duplicateOf: duplicate,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unknown timing and optional empty code cannot bypass the existing gate',
    (tester) async {
      ScanProvenance? p;
      await openPhoto(tester, (value) => p = value);
      expect(find.text('Review Photo'), findsOneWidget);
      expect(find.text('Specimen code (optional)'), findsNothing);
      await tester.tap(find.text('Analyze Photo'));
      await tester.pumpAndSettle();
      expect(p!.secondsAfterDipping, isNull);
      expect(p!.specimenCode, isNull);
      expect(p!.canSupportCurrentContext, isFalse);
    },
  );
  testWidgets(
    'known timing, explicit specimen confirmation and code preserve the gate',
    (tester) async {
      ScanProvenance? p;
      await openPhoto(tester, (value) => p = value);
      await tester.tap(find.byKey(const Key('photo_reading_time')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 seconds').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research Details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'CASE-01');
      await tester.tap(find.text('Analyze Photo'));
      await tester.pumpAndSettle();
      expect(p!.secondsAfterDipping, 60);
      expect(p!.specimenCode, 'CASE-01');
      expect(p!.canSupportCurrentContext, isTrue);
    },
  );
  testWidgets(
    'duplicate photo remains review only with a brief visible notice',
    (tester) async {
      ScanProvenance? p;
      await openPhoto(tester, (value) => p = value, duplicate: 'saved-01');
      expect(
        find.text('This photo is already saved. Repeat review only.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Analyze Photo'));
      await tester.pumpAndSettle();
      expect(p!.isDuplicate, isTrue);
      expect(p!.canSupportCurrentContext, isFalse);
    },
  );
  testWidgets('review dialog remains usable with large text on a small phone', (
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
          child: Scaffold(
            body: ScanProvenanceDialog(
              identity: ImageIdentity('a' * 64, 'b' * 64, 'c' * 16, null),
              source: 'import',
              duplicateCheckCompleted: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analyze Photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'unreliable kidney readings are not shown as confirmed negatives',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RenalResultsPage(
            scanResult: fixture.weak('PRO'),
            checklistResult: const ClinicalChecklistResult(
              selectedSymptoms: {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Results Considered'), findsOneWidget);
      expect(find.text('Unable to confirm'), findsWidgets);
      expect(find.text('Triggered rules'), findsNothing);
      expect(find.textContaining('TECH-'), findsNothing);
      expect(find.textContaining('URS-10T protein/blood'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/kidney_followup_phone.png'),
      );
    },
  );
  testWidgets(
    'About separates ordinary guidance from optional research metrics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const AboutPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Privacy and Data'), findsOneWidget);
      expect(find.textContaining('82.52%'), findsNothing);
      expect(find.text('Research Information'), findsOneWidget);
    },
  );
  testWidgets(
    'missing checklist answers stay unknown without conflicting symptom totals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OverallResultsPage(
            scanResult: fixture.baseScan(),
            clinicalChecklistResult: const ClinicalChecklistResult(
              selectedSymptoms: {},
              answers: {'fever': 'unsure'},
              questionnaireVersion: 'ui-test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to complete screening'), findsOneWidget);
      expect(find.textContaining('Symptoms reported:'), findsNothing);
      expect(find.textContaining('items selected'), findsNothing);
      await tester.ensureVisible(find.text('Checklist Review'));
      await tester.tap(find.text('Checklist Review'));
      await tester.pumpAndSettle();
      expect(find.text('Not sure'), findsOneWidget);
      expect(find.text('Not asked / unanswered'), findsWidgets);
      expect(find.text('No symptoms'), findsNothing);
    },
  );
}
