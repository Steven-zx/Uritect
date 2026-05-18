import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../widgets/dipstick_results_table.dart';

class OverallResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ClinicalChecklistResult clinicalChecklistResult;

  const OverallResultsPage({
    super.key,
    required this.scanResult,
    required this.clinicalChecklistResult,
  });

  String _riskIconAssetPath(String riskBucket) {
    switch (riskBucket) {
      case 'Low':
        return 'assets/photos/low risk.png';
      case 'Moderate':
        return 'assets/photos/moderate risk.png';
      case 'High':
        return 'assets/photos/high risk.png';
      default:
        return 'assets/photos/low risk.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ScreeningFusionEngine();
    final screeningAnalytes =
        ScreeningFusionEngine.buildAnalytesFromProbabilities(
          scanResult.screeningProbabilities,
        );
    final fusionResult = engine.fuse(
      analytes: screeningAnalytes,
      checklist: clinicalChecklistResult,
    );

    final tableRows = scanResult.rows;

    final selectedCount = clinicalChecklistResult.selectedSymptoms.values
        .where((v) => v)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 64),
                    Column(
                      children: [
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.primaryMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dipstick analysis and risk\nassessment',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _riskCard(context, fusionResult),
              if (fusionResult.hasEvidenceConflict) ...[
                const SizedBox(height: 12),
                _evidenceConflictCard(context, fusionResult),
              ],
              const SizedBox(height: 12),
              _conditionCard(context, fusionResult, selectedCount),
              const SizedBox(height: 12),
              DipstickResultsTable(rows: tableRows),
              const SizedBox(height: 12),
              _checklistAnswersCard(context),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'HOME',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _evidenceConflictCard(
    BuildContext context,
    ScreeningFusionResult fusionResult,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2C36B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB36B00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fusionResult.conflictTitle ?? 'Review needed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF704600),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fusionResult.conflictMessage ??
                      'Dipstick and checklist findings do not fully agree. Review the scan and patient context before making a decision.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF704600),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskCard(BuildContext context, ScreeningFusionResult fusionResult) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Level',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${fusionResult.riskBucket} Risk',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: fusionResult.riskBucket == 'Low'
                        ? AppColors.statusLow
                        : fusionResult.riskBucket == 'Moderate'
                        ? const Color(0xFFEB8C00)
                        : AppColors.statusHigh,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Posterior risk: ${(fusionResult.posteriorProbability * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              _riskIconAssetPath(fusionResult.riskBucket),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionCard(
    BuildContext context,
    ScreeningFusionResult fusionResult,
    int selectedCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Possible Condition',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryMain,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fusionResult.riskBucket == 'High'
                ? 'Elevated UTI Screening Concern'
                : 'Urinary Tract Infection (UTI)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF004E7A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Based on the 4-pad screening set and clinical checklist',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Symptoms reported: $selectedCount/${clinicalSymptoms.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistAnswersCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checklist Answers',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryMain,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final symptom in clinicalSymptoms)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(
                    clinicalChecklistResult.selectedSymptoms[symptom.id] == true
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color:
                        clinicalChecklistResult.selectedSymptoms[symptom.id] ==
                            true
                        ? AppColors.statusLow
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      symptom.label.replaceAll('\n', ' '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    clinicalChecklistResult.selectedSymptoms[symptom.id] == true
                        ? 'Yes'
                        : 'No',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          clinicalChecklistResult.selectedSymptoms[symptom
                                  .id] ==
                              true
                          ? AppColors.primaryMain
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
