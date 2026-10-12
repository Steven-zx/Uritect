import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/dipstick_results_data.dart';
import '../models/strip_reading_schedule.dart';

class DipstickResultsTable extends StatelessWidget {
  final List<DipstickResultRow> rows;
  final Map<String, double> analyteConfidences;
  final double requiredConfidence;
  final double? secondsAfterDipping;
  final bool scanVerified;
  const DipstickResultsTable({
    super.key,
    required this.rows,
    this.analyteConfidences = const {},
    this.requiredConfidence = .55,
    this.secondsAfterDipping,
    this.scanVerified = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Analyte readings',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        for (final row in rows) ...[
          const Divider(height: 1, color: AppColors.border),
          _row(row),
        ],
      ],
    ),
  );
  Widget _row(DipstickResultRow row) {
    final confidence = analyteConfidences[row.name];
    final timing = StripReadingSchedule.reportedTimeMatches(
      row.code,
      secondsAfterDipping,
    );
    final checked =
        scanVerified &&
        confidence != null &&
        confidence.isFinite &&
        confidence >= requiredConfidence &&
        timing;
    final result = checked
        ? (row.result.toLowerCase() == 'neg' ? 'Negative' : row.result)
        : 'Uncertain';
    return ExpansionTile(
      key: PageStorageKey('reading-${row.code}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(row.name, style: const TextStyle(fontSize: 14))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              result,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: checked ? AppColors.primaryDark : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Result: $result'),
              const SizedBox(height: 6),
              Text(
                checked
                    ? 'This reading passed the app’s required checks. It is not a diagnosis.'
                    : !timing
                    ? 'Reading time is unconfirmed. Check the strip instructions before repeating the photo.'
                    : 'This reading could not be confirmed. Retake a clear photo or seek professional review.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
