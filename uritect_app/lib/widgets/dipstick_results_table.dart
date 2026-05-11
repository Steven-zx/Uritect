import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/dipstick_results_data.dart';

class DipstickResultsTable extends StatelessWidget {
  final List<DipstickResultRow> rows;

  const DipstickResultsTable({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Parameter',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Result',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reference Range',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows) _DipstickResultTableRow(row: row),
        ],
      ),
    );
  }
}

class _DipstickResultTableRow extends StatelessWidget {
  final DipstickResultRow row;

  const _DipstickResultTableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final badgeColor = row.status == DipstickResultStatus.moderate
        ? const Color(0xFFF6B44D)
        : const Color(0xFF7AD98D);
    final badgeBackground = row.status == DipstickResultStatus.moderate
        ? const Color(0xFFFFE7C2)
        : const Color(0xFFDDF7E7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dipstickCodeColor(row.code).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    row.code,
                    style: TextStyle(
                      color: dipstickCodeColor(row.code),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.result,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.referenceRange,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}