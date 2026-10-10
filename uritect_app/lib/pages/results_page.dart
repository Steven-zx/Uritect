import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import '../widgets/strip_analysis_animation.dart';
import '../widgets/dipstick_results_table.dart';
import '../widgets/scan_context_notice.dart';
import 'dashboard_navigation.dart';
import 'symptom_checklist_page.dart';

class ResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ScanLocalization? localization;
  const ResultsPage({super.key, required this.scanResult, this.localization});

  @override
  Widget build(BuildContext context) {
    final hasReadings = scanResult.rows.isNotEmpty;
    final reliable = scanResult.isReliableForInterpretation;
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
                    reliable
                        ? 'Strip readings available'
                        : hasReadings
                        ? 'Readings need review'
                        : 'Please retake the photo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reliable
                        ? 'These are strip readings, not a diagnosis. Continue to the checklist for screening and safety guidance.'
                        : hasReadings
                        ? 'These readings cannot support a reliable interpretation. Retake the photo or complete the safety checklist.'
                        : 'No analyte results were produced. You can retake the photo or complete the safety checklist.',
                  ),
                  if (!hasReadings && scanResult.rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    Text(scanResult.rejectionReason!),
                  ],
                  if (!reliable) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Serious symptoms still require attention when a scan fails.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ScanContextNotice(scan: scanResult, compact: true),
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
            if (hasReadings) DipstickResultsTable(rows: scanResult.rows),
            if (scanResult.rejectionCode != null)
              ExpansionTile(
                title: const Text('Scan details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Scan check: ${scanResult.rejectionCode}'),
                  ),
                ],
              ),
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
}
