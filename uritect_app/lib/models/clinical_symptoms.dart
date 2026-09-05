import 'dart:math';

class ClinicalSymptom {
  final String id;
  final String label;
  final String category; // 'uti', 'systemic', or 'followup'
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

/// Conservative evidence set for clinical interpretation.
///
/// UTI symptom LR+ values are from Giesen et al. 2010, a systematic review of
/// women with suspected uncomplicated UTI. Unsupported symptoms are kept as
/// flags only with LR 1.00, and absent symptoms do not change odds.
const double _neutralLikelihoodRatio = 1.00;

final List<ClinicalSymptom> clinicalSymptoms = [
  ClinicalSymptom(
    id: 'dysuria',
    label: 'Burning sensation\nwhile urinating',
    category: 'uti',
    iconCode: 'dysuria',
    likelihoodRatioPositive: 1.30,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'frequency',
    label: 'Frequency',
    category: 'uti',
    iconCode: 'frequency',
    likelihoodRatioPositive: 1.10,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'urgency',
    label: 'Urgency',
    category: 'uti',
    iconCode: 'frequency',
    likelihoodRatioPositive: 1.22,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'suprapubic',
    label: 'Lower abdominal pain',
    category: 'uti',
    iconCode: 'suprapubic',
    likelihoodRatioPositive: _neutralLikelihoodRatio,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'hematuria',
    label: 'Visible hematuria',
    category: 'uti',
    iconCode: 'hematuria',
    likelihoodRatioPositive: 1.72,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'flank',
    label: 'Back pain',
    category: 'systemic',
    iconCode: 'flank',
    likelihoodRatioPositive: _neutralLikelihoodRatio,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'fever',
    label: 'Fever / Chills',
    category: 'systemic',
    iconCode: 'fever',
    likelihoodRatioPositive: _neutralLikelihoodRatio,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'edema',
    label: 'Peripheral edema',
    category: 'followup',
    iconCode: 'edema',
    likelihoodRatioPositive: _neutralLikelihoodRatio,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
  ),
  ClinicalSymptom(
    id: 'nausea',
    label: 'Nausea / Vomiting',
    category: 'systemic',
    iconCode: 'nausea',
    likelihoodRatioPositive: _neutralLikelihoodRatio,
    likelihoodRatioNegative: _neutralLikelihoodRatio,
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

  /// Compute a conservative UTI-only log-odds contribution from supported LRs.
  double computeLogOddsContribution() {
    double totalLogOdds = 0.0;

    for (final symptom in clinicalSymptoms.where((s) => s.category == 'uti')) {
      if (symptom.id == 'frequency' || symptom.id == 'urgency') {
        continue;
      }
      final isSelected = selectedSymptoms[symptom.id] ?? false;
      final lr = isSelected ? symptom.likelihoodRatioPositive : 1.0;
      totalLogOdds += log(lr.clamp(1e-6, 1e6));
    }

    final frequencySelected = selectedSymptoms['frequency'] == true;
    final urgencySelected = selectedSymptoms['urgency'] == true;
    if (frequencySelected || urgencySelected) {
      final lr = urgencySelected ? 1.22 : 1.10;
      totalLogOdds += log(lr);
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
