import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/renal_followup.dart';
import '../models/scan_model.dart';

class RenalResultsPage extends StatelessWidget {
  final ScanResult scanResult;
  final ClinicalChecklistResult checklistResult;

  const RenalResultsPage({
    super.key,
    required this.scanResult,
    required this.checklistResult,
  });

  @override
  Widget build(BuildContext context) {
    final result = const RenalFollowupEngine().evaluate(
      scanResult: scanResult,
      checklist: checklistResult,
    );
    final action = result.finalAction;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        foregroundColor: AppColors.primaryMain,
        title: const Text(
          'Renal Follow-up',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _actionPanel(context, result),
              const SizedBox(height: 14),
              _sectionTitle(context, 'Evidence used'),
              const SizedBox(height: 8),
              _evidencePanel(context, result),
              const SizedBox(height: 14),
              _sectionTitle(context, 'Triggered rules'),
              const SizedBox(height: 8),
              for (final rule in result.triggeredRules)
                _ruleTile(context, rule, rule.action == action),
              const SizedBox(height: 14),
              _limitationsPanel(context),
              const SizedBox(height: 14),
              Text(
                '${result.version} | ${result.stripProfile}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionPanel(BuildContext context, RenalFollowupResult result) {
    final color = _actionColor(result.finalAction);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_actionIcon(result.finalAction), color: color, size: 25),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  result.finalAction.heading,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            result.finalAction.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidencePanel(BuildContext context, RenalFollowupResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _evidenceRow(
            context,
            'Scan validity',
            result.scanValid ? 'Valid' : 'Invalid',
          ),
          _evidenceRow(
            context,
            'Protein',
            '${result.proteinCategory}${result.proteinReliable ? '' : ' (unreliable)'}',
          ),
          _evidenceRow(
            context,
            'Blood',
            '${result.bloodCategory}${result.bloodReliable ? '' : ' (unreliable)'}',
          ),
          _evidenceRow(
            context,
            'Supported profile',
            'URS-10T protein/blood at 60 seconds',
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _evidenceRow(
    BuildContext context,
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleTile(
    BuildContext context,
    TriggeredRenalRule rule,
    bool contributesFinalAction,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: contributesFinalAction
            ? const Color(0xFFEAF7F9)
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _actionColor(rule.action).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rule.id,
              style: TextStyle(
                color: _actionColor(rule.action),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.action.heading,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.explanation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    );
  }

  Widget _limitationsPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2C36B)),
      ),
      child: Text(
        'This output recommends follow-up action only. It does not diagnose kidney disease, calculate renal probability, stage CKD, or confirm hematuria. Quantitative urine ACR/PCR, microscopy, and professional assessment may be needed.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF704600),
          fontSize: 11.5,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.primaryMain,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  Color _actionColor(RenalAction action) => switch (action) {
    RenalAction.promptConsult => AppColors.statusHigh,
    RenalAction.retake => const Color(0xFFB36B00),
    RenalAction.consult => const Color(0xFFB36B00),
    RenalAction.repeatConfirm => AppColors.primaryMain,
    RenalAction.observe => AppColors.statusLow,
  };

  IconData _actionIcon(RenalAction action) => switch (action) {
    RenalAction.promptConsult => Icons.emergency_rounded,
    RenalAction.retake => Icons.replay_rounded,
    RenalAction.consult => Icons.medical_services_outlined,
    RenalAction.repeatConfirm => Icons.biotech_outlined,
    RenalAction.observe => Icons.visibility_outlined,
  };
}
