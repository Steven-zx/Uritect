import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import '../widgets/strip_analysis_animation.dart';
import '../widgets/dipstick_results_table.dart';
import '../widgets/research_details.dart';
import 'dashboard_navigation.dart';
import 'symptom_checklist_page.dart';

class ResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ScanLocalization? localization;
  const ResultsPage({super.key, required this.scanResult, this.localization});

  @override
  Widget build(BuildContext context) {
    final modelPaused =
        scanResult.rejectionCode == 'MODEL_ORIENTATION_REVIEW_REQUIRED';
    final hasReadings = scanResult.rows.isNotEmpty;
    final reliable = scanResult.isReliableForInterpretation;
    final currentContext =
        scanResult.provenance?.canSupportCurrentContext == true;
    final timingUnconfirmed = scanResult.rows.any(
      (r) => !scanResult.hasMatchingReportedReadingTime(r.code),
    );
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Dipstick Results'),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => returnToDashboard(context),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SymptomChecklistPage(scanResult: scanResult),
                  ),
                ),
                child: Text(
                  hasReadings
                      ? 'CONTINUE TO CHECKLIST'
                      : 'COMPLETE SAFETY CHECKLIST',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ScanAnalysisExitReason.scanAgain),
                      child: const Text('NEW SCAN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => returnToDashboard(context),
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: const Text('HOME'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: reliable
                    ? const Color(0xFFEAF7F9)
                    : const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelPaused
                        ? 'Classifier under review'
                        : reliable
                        ? (!currentContext
                              ? 'For research review only'
                              : timingUnconfirmed
                              ? 'Some results need review'
                              : 'Strip readings available')
                        : hasReadings
                        ? 'Readings need review'
                        : 'Please retake the photo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    modelPaused
                        ? 'Pad locations can be inspected below. Analyte readings are temporarily withheld while the model is reviewed.'
                        : reliable
                        ? (!currentContext
                              ? 'Photo or timing details are unconfirmed. These readings cannot support current-specimen screening.'
                              : timingUnconfirmed
                              ? 'Some readings need review. Check the reading time or retake the photo.'
                              : 'Review your readings, then complete the safety checklist. This is not a diagnosis.')
                        : hasReadings
                        ? 'Some readings are uncertain. Retake the photo for more reliable results.'
                        : 'Unable to read the dipstick reliably. Please retake the photo.',
                  ),
                  if (!hasReadings && _retakeHelp != null) ...[
                    const SizedBox(height: 8),
                    Text(_retakeHelp!),
                  ],
                  if (!reliable) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Serious symptoms still require attention when a scan fails.',
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'Research prototype · Not a diagnosis',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (localization?.regions.isNotEmpty == true)
              ExpansionTile(
                title: const Text('View sampled pad regions'),
                subtitle: const Text(
                  'Located regions do not guarantee valid readings.',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: StripAnalysisAnimation(
                      stage: 'complete',
                      imagePath: scanResult.imagePath,
                      localization: localization,
                    ),
                  ),
                ],
              ),
            if (scanResult.padsUnavailable != null &&
                scanResult.padsUnavailable! > 0) ...[
              Text(
                scanResult.status == 'invalid'
                    ? scanResult.padsDetected == 10
                          ? 'Located: 10/10 pads; results unavailable'
                          : 'Ten-pad detection not confirmed'
                    : 'Detected: ${scanResult.padsDetected ?? 0}/${(scanResult.padsDetected ?? 0) + (scanResult.padsUnavailable ?? 0)} pads',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (hasReadings)
              DipstickResultsTable(
                scanVerified:
                    scanResult.hasCompleteSafetyMetadata &&
                    currentContext &&
                    scanResult.status != 'invalid',
                rows: scanResult.rows,
                analyteConfidences: scanResult.analyteConfidences,
                requiredConfidence: scanResult.requiredAnalyteConfidence,
                secondsAfterDipping: scanResult.provenance?.secondsAfterDipping,
              ),
            ResearchDetails(scan: scanResult),
            const SizedBox(height: 12),
            const Text(
              'A completed checklist is required to save this scan to history.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String? get _retakeHelp => switch (scanResult.rejectionCode) {
    'IMAGE_TOO_DARK' => 'Use even lighting and avoid shadows.',
    'IMAGE_OVEREXPOSED' => 'Reduce glare and avoid direct light.',
    'IMAGE_BLURRED' => 'Tap the pads to focus and hold the phone steady.',
    'LOW_CONFIDENCE' => 'Retake in even lighting.',
    _ => null,
  };
}
