import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../models/renal_followup.dart';
import '../widgets/dipstick_results_table.dart';
import '../widgets/dataset_level_legend.dart';
import 'renal_results_page.dart';
import 'symptom_checklist_page.dart';
import 'dashboard_navigation.dart';
import 'protected_history_page.dart';
import '../widgets/scan_context_notice.dart';
import '../widgets/research_details.dart';
import '../services/scan_history_service.dart';

class OverallResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ClinicalChecklistResult clinicalChecklistResult;
  final BayesianUtiEstimate? savedUtiEstimate;
  final ScanHistoryService? historyService;
  final String? patientName;
  final VoidCallback? onEditPatientName;

  const OverallResultsPage({
    super.key,
    required this.scanResult,
    required this.clinicalChecklistResult,
    this.savedUtiEstimate,
    this.historyService,
    this.patientName,
    this.onEditPatientName,
  });

  @override
  Widget build(BuildContext context) {
    final engine = ScreeningFusionEngine();
    final screeningAnalytes = ScreeningFusionEngine.buildAnalytesFromRows(
      scanResult.rows,
    );
    final fusionResult = engine.fuse(
      analytes: screeningAnalytes,
      scanResult: scanResult,
      checklist: clinicalChecklistResult,
    );

    final tableRows = scanResult.rows;
    final renalResult = const RenalFollowupEngine().evaluate(
      scanResult: scanResult,
      checklist: clinicalChecklistResult,
    );

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Screening Summary'),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttons = <Widget>[
                if (savedUtiEstimate == null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final edited = await Navigator.of(context)
                          .push<ClinicalChecklistResult>(
                            MaterialPageRoute(
                              builder: (_) => SymptomChecklistPage(
                                scanResult: scanResult,
                                initialChecklistResult: clinicalChecklistResult,
                                returnToCaller: true,
                                historyService:
                                    historyService ??
                                    const ScanHistoryService(),
                              ),
                            ),
                          );
                      if (edited != null && context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => OverallResultsPage(
                              scanResult: scanResult,
                              clinicalChecklistResult: edited,
                              historyService: historyService,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Checklist'),
                  ),
                FilledButton.icon(
                  onPressed: () => returnToDashboard(context),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Home'),
                ),
              ];
              final stacked =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18;
              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      buttons[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: buttons[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onEditPatientName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  patientName ?? 'Unnamed patient',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Saved record name'),
                trailing: IconButton(
                  tooltip: patientName == null
                      ? 'Add patient name'
                      : 'Edit patient name',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditPatientName,
                ),
              ),
            _screeningStatus(context, fusionResult, renalResult),
            const SizedBox(height: 12),
            _riskCard(context, fusionResult),
            if (clinicalChecklistResult.hasIncompleteSafetyReview) ...[
              const SizedBox(height: 12),
              const Text(
                'Some health information is missing. Complete the checklist; warning symptoms cannot yet be excluded.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            // Keep actionable warnings visible rather than inside detail drawers.
            for (final item in fusionResult.interpretations.where(
              (item) =>
                  item.category != 'uti_screening' &&
                  (item.severity == 'high' ||
                      item.severity == 'moderate' ||
                      item.severity == 'caution'),
            ))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  tileColor: const Color(0xFFFFF7E6),
                  leading: Icon(
                    _iconForSeverity(item.severity),
                    color: _colorForSeverity(item.severity),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(item.message),
                ),
              ),
            if (fusionResult.hasEvidenceConflict) ...[
              const SizedBox(height: 12),
              _evidenceConflictCard(context, fusionResult),
            ],
            const SizedBox(height: 12),
            _bayesianEstimateCard(
              context,
              (!scanResult.modelDirectionReviewed ||
                      !scanResult.stripDirectionVerified)
                  ? fusionResult.utiEstimate
                  : savedUtiEstimate ?? fusionResult.utiEstimate,
            ),
            const SizedBox(height: 12),
            _renalFollowupCard(context, renalResult),
            if (savedUtiEstimate != null &&
                scanResult.modelDirectionReviewed &&
                scanResult.stripDirectionVerified)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Saved record. Follow-up guidance uses current rules.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            ScanContextNotice(scan: scanResult, compact: true),
            if (tableRows.isNotEmpty)
              ExpansionTile(
                title: const Text('Dipstick measurements'),
                subtitle: Text('${tableRows.length} analyte readings'),
                tilePadding: EdgeInsets.zero,
                children: [
                  DipstickResultsTable(
                    scanVerified:
                        scanResult.hasCompleteSafetyMetadata &&
                        scanResult.provenance?.canSupportCurrentContext ==
                            true &&
                        scanResult.status != 'invalid',
                    rows: tableRows,
                    analyteConfidences: scanResult.analyteConfidences,
                    requiredConfidence: scanResult.requiredAnalyteConfidence,
                    secondsAfterDipping:
                        scanResult.provenance?.secondsAfterDipping,
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No analyte readings are available. Retake the photo; symptom-based safety guidance still applies.',
                ),
              ),
            ExpansionTile(
              title: const Text('Safety and checklist details'),
              tilePadding: EdgeInsets.zero,
              children: [_conditionCard(context, fusionResult)],
            ),
            _checklistAnswersCard(context),
            const DatasetLevelLegend(),
            ResearchDetails(
              scan: scanResult,
              renal: renalResult,
              estimate:
                  (!scanResult.modelDirectionReviewed ||
                      !scanResult.stripDirectionVerified)
                  ? fusionResult.utiEstimate
                  : savedUtiEstimate ?? fusionResult.utiEstimate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _screeningStatus(
    BuildContext context,
    ScreeningFusionResult fusion,
    RenalFollowupResult renal,
  ) {
    final complete =
        fusion.utiEstimate.isCalculable &&
        renal.scanValid &&
        !clinicalChecklistResult.hasIncompleteSafetyReview;
    final someUncertain = scanResult.rows.any(
      (row) =>
          (scanResult.analyteConfidences[row.name] ?? 0) <
              scanResult.requiredAnalyteConfidence ||
          !scanResult.hasMatchingReportedReadingTime(row.code),
    );
    final title = !complete
        ? 'Unable to complete screening'
        : someUncertain
        ? 'Some results need review'
        : 'Screening completed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            !complete
                ? 'Some required readings or health information are unavailable. Follow the advice below.'
                : someUncertain
                ? 'Some information is available; uncertain readings are not confirmed findings.'
                : 'Required information has been reviewed. Follow-up advice does not confirm or rule out disease.',
          ),
          const SizedBox(height: 6),
          const Text(
            'Research prototype · Not a diagnosis',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _bayesianEstimateCard(
    BuildContext context,
    BayesianUtiEstimate estimate,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UTI-related screening',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          estimate.isCalculable
              ? 'A research result is available. This app cannot tell you your personal chance of a UTI.'
              : estimate.calculationStatus == 'not_designed'
              ? 'UTI screening is not available for this situation. A healthcare professional can assess your symptoms.'
              : 'UTI screening needs reliable readings and complete health information.',
        ),
        const SizedBox(height: 6),
        const Text(
          'This screening cannot confirm or rule out a UTI.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

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
                  'Kidney-related follow-up',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  renalResult.finalAction == RenalAction.observe
                      ? 'No kidney-related follow-up trigger identified'
                      : renalResult.finalAction.heading,
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
                  builder: (_) => savedUtiEstimate != null
                      ? ProtectedHistoryPage(
                          recordId: scanResult.id,
                          renalOnly: true,
                          historyService:
                              historyService ?? const ScanHistoryService(),
                        )
                      : RenalResultsPage(
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
                  'What to do next',
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
                      ? 'Based on the strip readings, checklist and safety checks.'
                      : 'Complete missing information or review uncertain readings. Serious symptoms still need medical attention.',
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
            'Your health information',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryMain,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Why this guidance was shown',
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
                      ],
                    ),
                  ),
                ],
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
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Review symptoms, safety and eligibility answers',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        children: [
          for (final symptom in clinicalSymptoms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                symptom.label.replaceAll('\n', ' '),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                clinicalChecklistResult.questionnaireVersion != null
                    ? clinicalChecklistResult.responseLabel(symptom.id)
                    : clinicalChecklistResult.selectedSymptoms[symptom.id] ==
                          true
                    ? 'Reported / confirmed'
                    : 'Not confirmed',
              ),
            ),
        ],
      ),
    );
  }
}
