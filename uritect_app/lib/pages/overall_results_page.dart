import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../models/renal_followup.dart';
import '../widgets/dipstick_results_table.dart';
import 'renal_results_page.dart';

class OverallResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ClinicalChecklistResult clinicalChecklistResult;

  const OverallResultsPage({
    super.key,
    required this.scanResult,
    required this.clinicalChecklistResult,
  });

  @override
  Widget build(BuildContext context) {
    final engine = ScreeningFusionEngine();
    final screeningAnalytes = ScreeningFusionEngine.buildAnalytesFromRows(
      scanResult.rows,
    );
    final fusionResult = engine.fuse(
      analytes: screeningAnalytes,
      checklist: clinicalChecklistResult,
    );

    final tableRows = scanResult.rows;
    final renalResult = const RenalFollowupEngine().evaluate(
      scanResult: scanResult,
      checklist: clinicalChecklistResult,
    );

    const symptomCategories = {
      'uti',
      'differential',
      'systemic',
      'renal',
      'renal_safety',
    };
    final relevantSymptoms = clinicalSymptoms
        .where((item) => symptomCategories.contains(item.category))
        .toList();
    final selectedCount = relevantSymptoms
        .where(
          (item) => clinicalChecklistResult.selectedSymptoms[item.id] == true,
        )
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
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Results',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dipstick analysis and clinical\ninterpretation',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _bayesianEstimateCard(context, fusionResult.utiEstimate),
              const SizedBox(height: 12),
              _riskCard(context, fusionResult),
              if (fusionResult.hasEvidenceConflict) ...[
                const SizedBox(height: 12),
                _evidenceConflictCard(context, fusionResult),
              ],
              const SizedBox(height: 12),
              _conditionCard(
                context,
                fusionResult,
                selectedCount,
                relevantSymptoms.length,
              ),
              const SizedBox(height: 12),
              _renalFollowupCard(context, renalResult),
              const SizedBox(height: 12),
              if (tableRows.isNotEmpty)
                DipstickResultsTable(rows: tableRows)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF2C36B)),
                  ),
                  child: const Text(
                    'Invalid scan: no analyte values were interpreted. Follow symptom-based safety advice and retake the strip scan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF704600), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              _checklistAnswersCard(context),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('EDIT CHECKLIST'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.primaryMain),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                      borderRadius: BorderRadius.circular(8),
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

  Widget _bayesianEstimateCard(
    BuildContext context,
    BayesianUtiEstimate estimate,
  ) {
    final calculated = estimate.isCalculable;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: calculated ? const Color(0xFFEAF7F9) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: calculated ? const Color(0xFF9DCDD2) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: calculated
                      ? AppColors.primaryMain
                      : const Color(0xFFE9EEF2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  calculated
                      ? Icons.calculate_rounded
                      : Icons.info_outline_rounded,
                  color: calculated ? Colors.white : AppColors.textSecondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estimate.modelVersion ==
                              ScreeningFusionEngine.maleModelVersion
                          ? 'Male Bayesian UTI Research Estimate'
                          : 'Female Bayesian UTI Research Estimate',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      calculated
                          ? estimate.modelVersion ==
                                    ScreeningFusionEngine.maleModelVersion
                                ? 'Provisional male model based on culture-referenced evidence'
                                : 'Calculated from the female v1.1 evidence hierarchy'
                          : 'No ordinary estimate was calculated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (calculated) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${estimate.posteriorPercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'screening estimate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Starting prior: ${(estimate.priorProbability * 100).toStringAsFixed(0)}%',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Evidence applied',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final factor in estimate.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'LR ${factor.likelihoodRatio.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factor.finding,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            factor.group,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            Text(
              estimate.modelVersion == ScreeningFusionEngine.maleModelVersion
                  ? 'Prior odds x one selected dipstick-threshold LR = posterior odds'
                  : 'Prior odds x selected dipstick LR x selected symptom LR = posterior odds',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ] else
            Text(
              estimate.statusReason,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            estimate.modelVersion == ScreeningFusionEngine.maleModelVersion
                ? 'Provisional ordered-threshold research approximation. It is not locally calibrated, is not a diagnosis, and does not recommend treatment.'
                : 'Screening support only. This result is not a diagnosis and does not recommend antibiotics or other treatment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4E5962),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            estimate.modelVersion,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renalFollowupCard(
    BuildContext context,
    RenalFollowupResult renalResult,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medical_services_outlined,
            color: AppColors.primaryMain,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Renal follow-up',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  renalResult.finalAction.heading,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View renal follow-up details',
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primaryMain,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RenalResultsPage(
                    scanResult: scanResult,
                    checklistResult: clinicalChecklistResult,
                  ),
                ),
              );
            },
          ),
        ],
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
        borderRadius: BorderRadius.circular(8),
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
                  'Clinical Action',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fusionResult.clinicalAction,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: fusionResult.clinicalAction == 'Observe for symptoms'
                        ? AppColors.statusLow
                        : fusionResult.clinicalAction ==
                              'Prompt medical consultation suggested'
                        ? AppColors.statusHigh
                        : fusionResult.clinicalAction ==
                              'Consultation suggested'
                        ? const Color(0xFFEB8C00)
                        : AppColors.primaryMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  fusionResult.utiEstimate.isCalculable
                      ? 'Based on the evidence and safety pathways shown below'
                      : fusionResult.utiEstimate.statusReason,
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
          Icon(
            fusionResult.clinicalAction ==
                    'Prompt medical consultation suggested'
                ? Icons.emergency_rounded
                : fusionResult.clinicalAction == 'Consultation suggested'
                ? Icons.medical_services_outlined
                : fusionResult.clinicalAction == 'Insufficient evidence'
                ? Icons.help_outline_rounded
                : Icons.visibility_outlined,
            color:
                fusionResult.clinicalAction ==
                    'Prompt medical consultation suggested'
                ? AppColors.statusHigh
                : AppColors.primaryMain,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _conditionCard(
    BuildContext context,
    ScreeningFusionResult fusionResult,
    int selectedCount,
    int symptomTotal,
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
            'Safety and Clinical Context',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryMain,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Separated evidence outputs',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          for (final interpretation in fusionResult.interpretations.where(
            (item) => item.category != 'uti_screening',
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _iconForSeverity(interpretation.severity),
                    size: 16,
                    color: _colorForSeverity(interpretation.severity),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          interpretation.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF004E7A),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          interpretation.message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.25,
                              ),
                        ),
                        if (interpretation.evidence.isNotEmpty)
                          Text(
                            interpretation.evidence.join(' | '),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Symptoms reported: $selectedCount/$symptomTotal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSeverity(String severity) {
    switch (severity) {
      case 'high':
        return Icons.priority_high_rounded;
      case 'moderate':
        return Icons.report_problem_rounded;
      case 'caution':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.statusHigh;
      case 'moderate':
        return const Color(0xFFEB8C00);
      case 'caution':
        return AppColors.primaryMain;
      default:
        return AppColors.statusLow;
    }
  }

  Widget _checklistAnswersCard(BuildContext context) {
    final selectedCount = clinicalSymptoms
        .where(
          (symptom) =>
              clinicalChecklistResult.selectedSymptoms[symptom.id] == true,
        )
        .length;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: const Icon(
          Icons.fact_check_outlined,
          color: AppColors.primaryMain,
        ),
        title: Text(
          'Checklist Review',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$selectedCount of ${clinicalSymptoms.length} items selected',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        children: [
          for (final symptom in clinicalSymptoms)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    clinicalChecklistResult.selectedSymptoms[symptom.id] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clinicalChecklistResult.selectedSymptoms[symptom.id] == true
                        ? 'Selected'
                        : symptom.category == 'uti_eligibility'
                        ? 'Not confirmed'
                        : 'Not selected',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          clinicalChecklistResult.selectedSymptoms[symptom
                                  .id] ==
                              true
                          ? AppColors.primaryMain
                          : AppColors.textSecondary,
                      fontSize: 10,
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
