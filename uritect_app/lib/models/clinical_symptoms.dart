import 'dart:math';

class ClinicalSymptom {
  final String id;
  final String label;
  final String
  category; // 'lut' = Lower Urinary Tract, 'renal' = Renal/Systemic
  final String iconCode; // For UI rendering
  final double likelihoodRatioPositive; // LR+ when symptom is present
  final double likelihoodRatioNegative; // LR- when symptom is absent

  const ClinicalSymptom({
    required this.id,
    required this.label,
    required this.category,
    required this.iconCode,
    required this.likelihoodRatioPositive,
    required this.likelihoodRatioNegative,
  });
}

/// Reference set of 8 clinical symptoms with Bayesian LR values.
/// LR+ > 1.0 increases post-test probability; LR- < 1.0 decreases it.
/// Absence uses a mild shared LR- so missing symptoms moderate risk without
/// overpowering objective dipstick findings.
const double _absentSymptomLikelihoodRatio = 0.95;

final List<ClinicalSymptom> clinicalSymptoms = [
  // Category 1: Lower Urinary Tract Symptoms (UTI Focus)
  ClinicalSymptom(
    id: 'dysuria',
    label: 'Burning sensation\nwhile urinating',
    category: 'lut',
    iconCode: 'dysuria',
    likelihoodRatioPositive: 2.8, // Strong indicator of UTI
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'frequency',
    label: 'Frequency / Urgency',
    category: 'lut',
    iconCode: 'frequency',
    likelihoodRatioPositive: 2.2,
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'suprapubic',
    label: 'Lower abdominal pain',
    category: 'lut',
    iconCode: 'suprapubic',
    likelihoodRatioPositive: 2.0,
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'hematuria',
    label: 'Visible hematuria',
    category: 'lut',
    iconCode: 'hematuria',
    likelihoodRatioPositive: 5.8, // Very strong indicator
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  // Category 2: Renal and Systemic "Red Flags"
  ClinicalSymptom(
    id: 'flank',
    label: 'Back pain',
    category: 'renal',
    iconCode: 'flank',
    likelihoodRatioPositive: 5.0, // High-weight pyelonephritis indicator
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'fever',
    label: 'Fever / Chills',
    category: 'renal',
    iconCode: 'fever',
    likelihoodRatioPositive: 3.5, // Systemic involvement marker
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'edema',
    label: 'Peripheral edema',
    category: 'renal',
    iconCode: 'edema',
    likelihoodRatioPositive: 2.5,
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'nausea',
    label: 'Nausea / Vomiting',
    category: 'renal',
    iconCode: 'nausea',
    likelihoodRatioPositive: 2.2,
    likelihoodRatioNegative: _absentSymptomLikelihoodRatio,
  ),
];

class ClinicalChecklistResult {
  final Map<String, bool> selectedSymptoms; // id -> selected

  const ClinicalChecklistResult({required this.selectedSymptoms});

  Map<String, dynamic> toJson() {
    return {'selectedSymptoms': selectedSymptoms};
  }

  factory ClinicalChecklistResult.fromJson(Map<String, dynamic> json) {
    final raw = json['selectedSymptoms'] as Map<String, dynamic>? ?? const {};
    return ClinicalChecklistResult(
      selectedSymptoms: {
        for (final symptom in clinicalSymptoms)
          symptom.id: raw[symptom.id] == true,
      },
    );
  }

  /// Compute Bayesian log-odds contribution from selected symptoms using LRs.
  double computeLogOddsContribution() {
    double totalLogOdds = 0.0;
    for (final symptom in clinicalSymptoms) {
      final isSelected = selectedSymptoms[symptom.id] ?? false;
      final lr = isSelected
          ? symptom.likelihoodRatioPositive
          : symptom.likelihoodRatioNegative;
      totalLogOdds += log(lr.clamp(1e-6, 1e6)); // Avoid log(0)
    }
    return totalLogOdds;
  }

  factory ClinicalChecklistResult.empty() {
    return ClinicalChecklistResult(
      selectedSymptoms: {for (final s in clinicalSymptoms) s.id: false},
    );
  }

  factory ClinicalChecklistResult.placeholder() {
    return ClinicalChecklistResult.empty();
  }
}
