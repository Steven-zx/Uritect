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
    id: 'uti_eligible_female',
    label: 'Female',
    category: 'uti_sex',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_male',
    label: 'Male',
    category: 'uti_sex',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_age_18_64',
    label: 'Patient is 18 to 64 years old',
    category: 'uti_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_nonpregnant',
    label: 'Patient is confirmed not pregnant',
    category: 'uti_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_no_catheter',
    label: 'Patient does not have a urinary catheter',
    category: 'uti_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_no_urologic_abnormality',
    label: 'No known urinary tract abnormality',
    category: 'uti_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_eligible_not_immunocompromised',
    label: 'Patient is not immunocompromised',
    category: 'uti_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_male_no_diabetes',
    label: 'Patient does not have diabetes',
    category: 'uti_male_eligibility',
    iconCode: 'eligibility',
  ),
  const ClinicalSymptom(
    id: 'uti_male_no_suspected_sti',
    label: 'No suspected sexually transmitted infection',
    category: 'uti_male_eligibility',
    iconCode: 'eligibility',
  ),
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
  const ClinicalSymptom(
    id: 'blood_clots',
    label: 'Blood clots in urine',
    category: 'renal_safety',
    iconCode: 'blood_clots',
  ),
  const ClinicalSymptom(
    id: 'unable_to_urinate',
    label: 'Difficulty or inability to urinate',
    category: 'renal_safety',
    iconCode: 'urinary_obstruction',
  ),
  const ClinicalSymptom(
    id: 'reduced_urine_output',
    label: 'Markedly reduced or absent urine output',
    category: 'renal_safety',
    iconCode: 'reduced_output',
  ),
  const ClinicalSymptom(
    id: 'edema',
    label: 'Edema or unusual swelling',
    category: 'renal',
    iconCode: 'edema',
  ),
  const ClinicalSymptom(
    id: 'persistent_edema',
    label: 'Swelling is persistent or unexplained',
    category: 'renal',
    iconCode: 'edema',
  ),
  const ClinicalSymptom(
    id: 'shortness_of_breath',
    label: 'Shortness of breath',
    category: 'renal_safety',
    iconCode: 'breathing',
  ),
  const ClinicalSymptom(
    id: 'cannot_hydrate_or_medicate',
    label: 'Vomiting prevents fluids or oral medication',
    category: 'renal_safety',
    iconCode: 'hydration',
  ),
  const ClinicalSymptom(
    id: 'confusion_fainting_weakness',
    label: 'Confusion, fainting, or severe weakness',
    category: 'renal_safety',
    iconCode: 'serious_illness',
  ),
  const ClinicalSymptom(
    id: 'severe_flank_abdominal_pain',
    label: 'Severe flank or abdominal pain',
    category: 'renal_safety',
    iconCode: 'severe_pain',
  ),
  const ClinicalSymptom(
    id: 'menstruation_or_vaginal_bleeding',
    label: 'Menstruation or vaginal bleeding',
    category: 'interference',
    iconCode: 'interference',
  ),
  const ClinicalSymptom(
    id: 'possible_contamination',
    label: 'Possible specimen contamination',
    category: 'interference',
    iconCode: 'interference',
  ),
  const ClinicalSymptom(
    id: 'strenuous_exercise',
    label: 'Recent strenuous exercise',
    category: 'interference',
    iconCode: 'exercise',
  ),
  const ClinicalSymptom(
    id: 'dehydration',
    label: 'Possible dehydration',
    category: 'interference',
    iconCode: 'hydration',
  ),
  const ClinicalSymptom(
    id: 'acute_illness',
    label: 'Current acute illness',
    category: 'interference',
    iconCode: 'acute_illness',
  ),
  const ClinicalSymptom(
    id: 'managed_or_possible_uti',
    label: 'Possible or clinically managed UTI',
    category: 'interference',
    iconCode: 'uti_context',
  ),
  const ClinicalSymptom(
    id: 'repeat_protein_present',
    label: 'Protein remained present on a properly collected repeat test',
    category: 'repeat_history',
    iconCode: 'repeat_test',
  ),
  const ClinicalSymptom(
    id: 'repeat_blood_present',
    label: 'Blood remained present on a properly collected repeat test',
    category: 'repeat_history',
    iconCode: 'repeat_test',
  ),
  const ClinicalSymptom(
    id: 'blood_microscopy_confirmed',
    label: 'Blood was confirmed by urine microscopy',
    category: 'repeat_history',
    iconCode: 'microscopy',
  ),
  const ClinicalSymptom(
    id: 'repeat_abnormal_resolved',
    label: 'A previous protein finding became negative on repeat',
    category: 'repeat_history',
    iconCode: 'repeat_test',
  ),
  const ClinicalSymptom(
    id: 'strip_expired',
    label: 'Strip was expired',
    category: 'test_quality',
    iconCode: 'strip_quality',
  ),
  const ClinicalSymptom(
    id: 'strip_damaged',
    label: 'Strip or reagent pads were damaged',
    category: 'test_quality',
    iconCode: 'strip_quality',
  ),
  const ClinicalSymptom(
    id: 'read_outside_60_seconds',
    label: 'Protein or blood was scanned outside 60 seconds',
    category: 'test_quality',
    iconCode: 'timer',
  ),
  const ClinicalSymptom(
    id: 'unsupported_strip',
    label: 'Strip was not the supported URS-10T profile',
    category: 'test_quality',
    iconCode: 'strip_quality',
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
