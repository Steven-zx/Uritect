import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Category reference only. No sampled colours, relabeling, or model inputs.
class DatasetLevelLegend extends StatelessWidget {
  const DatasetLevelLegend({super.key});
  static const levels = <String, List<String>>{
    "Leukocytes": ["Neg", "Trace 15", "Small 70", "Moderate 125", "Large 500"],
    "Nitrite": ["Neg", "Positive"],
    "Urobilinogen": ["3.2", "16", "32", "64", "128"],
    "Protein": ["Neg", "Trace", "0.3", "1.0", "3.0", ">=20.0"],
    "pH": ["5.0", "6.0", "6.5", "7.0", "7.5", "8.0", "8.5"],
    "Blood": [
      "Neg",
      "Non-hemolyzed 10",
      "Hemolyzed 10",
      "Small 25",
      "Moderate 80",
      "Large 200",
    ],
    "Specific Gravity": [
      "1.000",
      "1.005",
      "1.010",
      "1.015",
      "1.020",
      "1.025",
      "1.030",
    ],
    "Ketone": [
      "Neg",
      "Trace 0.5",
      "Small 1.5",
      "Moderate 4.0",
      "8.0",
      "Large 16",
    ],
    "Bilirubin": ["Neg", "Small 17", "Moderate 50", "Large 100"],
    "Glucose": ["Neg", "Trace 5", "15 +", "30 ++", "60 +++", "110 ++++"],
  };
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Dataset level reference'),
    leading: const Icon(Icons.list_alt_outlined, color: AppColors.primaryMain),
    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
    children: [
      const Text(
        'Category labels used by the dataset. This is not a verified strip color chart or a normal-range guide. Use the chart supplied with your strip for manual comparison. Color swatches will be added after the reference chart is supplied.',
      ),
      const SizedBox(height: 12),
      for (final entry in levels.entries)
        ExpansionTile(
          title: Text(entry.key),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final level in entry.value)
                    Chip(label: Text(level == 'Neg' ? 'Negative' : level)),
                ],
              ),
            ),
          ],
        ),
    ],
  );
}
