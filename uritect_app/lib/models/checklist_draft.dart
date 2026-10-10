import 'clinical_symptoms.dart';

class ChecklistDraft {
  final Map<String, String> answers = {};

  void answer(String id, String value) {
    final previous = answers[id];
    answers[id] = value;
    if (id == 'safety_review' && value == 'no') {
      for (final key in checklistSafetyIds) {
        answers[key] = 'no';
      }
      answers['persistent_edema'] = 'no';
    } else if (id == 'safety_review' && value == 'yes' && previous != value) {
      for (final key in checklistSafetyIds) {
        answers.remove(key);
      }
      answers.remove('persistent_edema');
    }
    if (id == 'quality_review' && value == 'no') {
      for (final item in clinicalSymptoms.where(
        (s) => s.category == 'test_quality',
      )) {
        answers[item.id] = 'no';
      }
    }
    if (id == 'edema' && value == 'no') answers['persistent_edema'] = 'no';
    if (id == 'renal_history' && value == 'no') {
      for (final item in clinicalSymptoms.where(
        (s) => s.category == 'repeat_history',
      )) {
        answers.remove(item.id);
      }
    }
  }

  void sex(String value) {
    answers['uti_eligible_female'] = value == 'female' ? 'yes' : 'no';
    answers['uti_eligible_male'] = value == 'male' ? 'yes' : 'no';
    for (final id
        in value == 'male'
            ? [
                'uti_eligible_nonpregnant',
                'vaginal_discharge',
                'vaginal_irritation',
                'menstruation_or_vaginal_bleeding',
              ]
            : ['uti_male_no_diabetes', 'uti_male_no_suspected_sti']) {
      answers.remove(id);
    }
  }

  bool get female => answers['uti_eligible_female'] == 'yes';
  bool get male => answers['uti_eligible_male'] == 'yes';
  ClinicalChecklistResult result() => ClinicalChecklistResult(
    selectedSymptoms: {
      for (final s in clinicalSymptoms) s.id: answers[s.id] == 'yes',
    },
    answers: Map.unmodifiable(answers),
    questionnaireVersion: 'progressive_checklist_v1_20261005',
  );
}
