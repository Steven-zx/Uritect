import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/services/scan_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/scan_analysis_exit_reason.dart';
import 'package:uritect_app/pages/analyzing_page.dart';

void main() {
  testWidgets('new scan returns retake through invalid analysis', (
    tester,
  ) async {
    ScanAnalysisExitReason? returnedReason;
    bool finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  returnedReason = await Navigator.of(context)
                      .push<ScanAnalysisExitReason>(
                        MaterialPageRoute(
                          builder: (_) => const AnalyzingPage(
                            imagePath: 'old_photo.png',
                            analysisService: _InvalidAnalysis(),
                          ),
                        ),
                      );
                  finished = true;
                },
                child: const Text('START'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('START'));
    for (
      var attempt = 0;
      attempt < 100 && find.text('NEW SCAN').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(
      find.text('NEW SCAN'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(
      finished,
      isFalse,
      reason: 'Capture must wait until results return.',
    );
    await tester.ensureVisible(find.text('NEW SCAN'));
    await tester.tap(find.text('NEW SCAN'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(returnedReason, ScanAnalysisExitReason.scanAgain);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('NEW SCAN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _InvalidAnalysis extends ScanAnalysisService {
  const _InvalidAnalysis();
  @override
  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double progress, String stage)? onProgress,
  }) async {
    throw StateError('INVALID_IMAGE: no strip');
  }
}
