class ClinicalSymptom {
  final String id;
  final String label;
  final String category;
  final String iconCode;

  const ClinicalSymptom({
    required this.id,
    required this.label,
    required this.category,
    required this.iconCode,
  });
}

final List<ClinicalSymptom> clinicalSymptoms = [
  const ClinicalSymptom(
    id: 'dysuria',
    label: 'Burning sensation\nwhile urinating',
    category: 'uti',
    iconCode: 'dysuria',
  ),
  const ClinicalSymptom(
    id: 'frequency',
    label: 'Frequency',
    category: 'uti',
    iconCode: 'frequency',
  ),
  const ClinicalSymptom(
    id: 'urgency',
    label: 'Urgency',
    category: 'uti',
    iconCode: 'frequency',
  ),
  const ClinicalSymptom(
    id: 'suprapubic',
    label: 'Lower abdominal pain',
    category: 'uti',
    iconCode: 'suprapubic',
  ),
  const ClinicalSymptom(
    id: 'hematuria',
    label: 'Visible hematuria',
    category: 'uti',
    iconCode: 'hematuria',
  ),
  const ClinicalSymptom(
    id: 'vaginal_discharge',
    label: 'Vaginal discharge',
    category: 'differential',
    iconCode: 'discharge',
  ),
  const ClinicalSymptom(
    id: 'vaginal_irritation',
    label: 'Vaginal irritation',
    category: 'differential',
    iconCode: 'irritation',
  ),
  const ClinicalSymptom(
    id: 'flank',
    label: 'Back pain',
    category: 'systemic',
    iconCode: 'flank',
  ),
  const ClinicalSymptom(
    id: 'fever',
    label: 'Fever / Chills',
    category: 'systemic',
    iconCode: 'fever',
  ),
  const ClinicalSymptom(
    id: 'nausea',
    label: 'Nausea / Vomiting',
    category: 'systemic',
    iconCode: 'nausea',
  ),
];

class ClinicalChecklistResult {
  final Map<String, bool> selectedSymptoms;

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

  factory ClinicalChecklistResult.empty() {
    return ClinicalChecklistResult(
      selectedSymptoms: {for (final s in clinicalSymptoms) s.id: false},
    );
  }

  factory ClinicalChecklistResult.placeholder() {
    return ClinicalChecklistResult.empty();
  }
}
