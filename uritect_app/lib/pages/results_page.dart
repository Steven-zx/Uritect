import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import '../widgets/strip_analysis_animation.dart';
import '../widgets/dipstick_results_table.dart';
import 'dashboard_navigation.dart';
import 'symptom_checklist_page.dart';

class ResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ScanLocalization? localization;
  const ResultsPage({super.key, required this.scanResult, this.localization});

  @override
  Widget build(BuildContext context) {
    final hasReadings = scanResult.rows.isNotEmpty;
    final dipstickDetected =
        scanResult.padsDetected == 10 ||
        (scanResult.padsDetected == null && localization?.regions.length == 10);
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
                onPressed: !dipstickDetected
                    ? null
                    : () => Navigator.of(context).push(
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
            if (localization?.regions.isNotEmpty == true)
              ExpansionTile(
                title: const Text('View sampled pad regions'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: StripAnalysisAnimation(
                      stage: 'complete',
                      showCaptions: false,
                      imagePath: scanResult.imagePath,
                      localization: localization,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (hasReadings)
              DipstickResultsTable(rows: scanResult.rows, showDetails: false)
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dipstickDetected
                          ? 'Unable to read dipstick'
                          : 'Ten-pad dipstick not detected',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No readings available. Please take a new photo.',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
