import 'package:flutter/material.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../models/renal_followup.dart';
import '../models/strip_reading_schedule.dart';

/// Kept inside the current screen so saved-history privacy covers these values.
class ResearchDetails extends StatelessWidget {
  final ScanResult scan;
  final BayesianUtiEstimate? estimate;
  final RenalFollowupResult? renal;
  const ResearchDetails({
    super.key,
    required this.scan,
    this.estimate,
    this.renal,
  });

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('research_details'),
    title: const Text('Research Details'),
    subtitle: const Text('Optional technical information'),
    tilePadding: EdgeInsets.zero,
    shape: const Border(),
    collapsedShape: const Border(),
    childrenPadding: const EdgeInsets.only(bottom: 16),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unvalidated research outputs. These are not a diagnosis or a clinically calibrated probability.',
            ),
            const SizedBox(height: 12),
            Text('Classifier: ${scan.modelVersion}'),
            Text(StripReadingSchedule.guidance),
            const Text(
              'Anti-VC is an owner-reported label claim; its protection limits are unverified.',
            ),
            if (scan.rejectionCode != null)
              Text('Scan check: ${scan.rejectionCode}'),
            if (scan.rejectionReason != null) Text(scan.rejectionReason!),
            if (scan.provenance?.specimenCode != null)
              Text('Specimen code: ${scan.provenance!.specimenCode}'),
            if (scan.provenance?.secondsAfterDipping != null)
              Text(
                'Reported timing: ${scan.provenance!.secondsAfterDipping} s',
              ),
            for (final row in scan.rows)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row.name}: ${row.result}'),
                    Text('Reference label: ${row.referenceRange}'),
                    if (scan.analyteConfidences[row.name] != null)
                      Text(
                        'Vote confidence: ${(scan.analyteConfidences[row.name]! * 100).toStringAsFixed(0)}%',
                      ),
                    if (scan.nearestTrainingDistances[row.name] != null)
                      Text(
                        'Training distance: ${scan.nearestTrainingDistances[row.name]}',
                      ),
                  ],
                ),
              ),
            if (estimate != null) ...[
              const SizedBox(height: 16),
              Text(estimate!.modelVersion),
              if (estimate!.isCalculable) ...[
                Text('${estimate!.posteriorPercent.toStringAsFixed(1)}%'),
                const Text(
                  'Research calculation only; not a validated personal UTI probability.',
                ),
                Text(
                  'Starting prior: ${(estimate!.priorProbability * 100).toStringAsFixed(1)}%',
                ),
                for (final factor in estimate!.factors)
                  Text(
                    'LR ${factor.likelihoodRatio.toStringAsFixed(2)} — ${factor.finding}',
                  ),
              ] else
                Text(estimate!.statusReason),
              const Text(
                'Combining symptom and dipstick LRs, male ordered branches and transfer of the study prior and LRs remain assumptions. No local culture-confirmed calibration has been performed.',
              ),
            ],
            if (renal != null) ...[
              const SizedBox(height: 16),
              Text('${renal!.version} | ${renal!.stripProfile}'),
              for (final rule in renal!.triggeredRules)
                Text('${rule.id}: ${rule.explanation}'),
            ],
          ],
        ),
      ),
    ],
  );
}
