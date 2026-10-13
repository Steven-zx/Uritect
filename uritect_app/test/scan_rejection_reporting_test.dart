import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/pages/results_page.dart';

void main() {
  test('known confidence rejection retains localization count', () {
    final failure = ScanAnalysisFailure(
      code: 'LOW_CONFIDENCE',
      guidance: 'All ten pads were located, but classification was uncertain.',
      padsDetected: 10,
    );
    expect(ScanAnalysisFailure.fromError(failure), same(failure));
    expect(failure.padsDetected, 10);
    final scan = ScanResult.empty(imagePath: 'test.jpg').copyWith(
      status: 'invalid',
      padsDetected: failure.padsDetected,
      padsUnavailable: 10,
      rejectionCode: failure.code,
      rejectionReason: failure.guidance,
    );
    final restored = ScanResult.fromJson(scan.toJson());
    expect(restored.padsDetected, 10);
    expect(restored.rejectionCode, 'LOW_CONFIDENCE');
    expect(restored.rejectionReason, failure.guidance);
    expect(restored.isReliableForInterpretation, isFalse);
  });

  test('legacy and localization errors do not invent a zero pad count', () {
    for (final message in [
      'INVALID_IMAGE: Could not locate a complete ten-pad strip.',
      'LOW_CONFIDENCE: Protein result is low confidence.',
    ]) {
      expect(
        ScanAnalysisFailure.fromError(StateError(message)).padsDetected,
        isNull,
      );
    }
    final legacy = ScanResult.empty(imagePath: 'old.jpg').toJson()
      ..remove('rejectionCode')
      ..remove('rejectionReason');
    expect(ScanResult.fromJson(legacy).rejectionReason, isNull);
  });

  testWidgets(
    'rejected results distinguish located pads from unreadable results',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResultsPage(
            scanResult: ScanResult.empty(imagePath: 'test.jpg').copyWith(
              status: 'invalid',
              padsDetected: 10,
              padsUnavailable: 10,
              rejectionCode: 'LOW_CONFIDENCE',
              rejectionReason:
                  'All ten pads were located; retake in even lighting.',
            ),
          ),
        ),
      );
      expect(
        find.text('No readings available. Please take a new photo.'),
        findsOneWidget,
      );
      expect(find.text('Research Details'), findsNothing);
      expect(find.text('Detected: 0/10 pads'), findsNothing);
      expect(find.text('COMPLETE SAFETY CHECKLIST'), findsOneWidget);
      expect(find.text('Unable to read dipstick'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unmeasured localization count remains unconfirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          scanResult: ScanResult.empty(imagePath: 'test.jpg').copyWith(
            status: 'invalid',
            padsUnavailable: 10,
            rejectionCode: 'STRIP_NOT_CONFIRMED',
            rejectionReason: 'Keep the whole strip in focus.',
          ),
        ),
      ),
    );
    expect(
      find.text('No readings available. Please take a new photo.'),
      findsOneWidget,
    );
    expect(find.text('Detected: 0/10 pads'), findsNothing);
    expect(find.text('Ten-pad dipstick not detected'), findsOneWidget);
    expect(find.text('Dataset level reference'), findsNothing);
    expect(find.text('Research Details'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('COMPLETE SAFETY CHECKLIST'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero detected pads cannot open the checklist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          scanResult: ScanResult.empty(imagePath: '').copyWith(
            status: 'invalid',
            padsDetected: 0,
            rejectionCode: 'IMAGE_BLANK',
          ),
        ),
      ),
    );
    final heading = tester.widget<Text>(
      find.text('Ten-pad dipstick not detected'),
    );
    expect(heading.style?.fontWeight, FontWeight.w700);
    expect(heading.style?.fontSize, 24);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
    expect(find.text('HOME'), findsOneWidget);
  });
}
