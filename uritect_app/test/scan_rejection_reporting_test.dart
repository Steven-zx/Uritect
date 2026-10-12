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
        find.text('Located: 10/10 pads; results unavailable'),
        findsOneWidget,
      );
      expect(find.text('Scan check: LOW_CONFIDENCE'), findsNothing);
      await tester.ensureVisible(find.text('Research Details'));
      await tester.tap(find.text('Research Details'));
      await tester.pumpAndSettle();
      expect(find.text('Scan check: LOW_CONFIDENCE'), findsOneWidget);
      expect(find.text('Detected: 0/10 pads'), findsNothing);
      expect(find.text('COMPLETE SAFETY CHECKLIST'), findsOneWidget);
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
    expect(find.text('Ten-pad detection not confirmed'), findsOneWidget);
    expect(find.text('Detected: 0/10 pads'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
