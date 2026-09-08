import 'clinical_symptoms.dart';
import 'dipstick_results_data.dart';

class ScreeningAnalyteResult {
  final String code;
  final String name;
  final String displayValue;

  const ScreeningAnalyteResult({
    required this.code,
    required this.name,
    required this.displayValue,
  });
}

class ClinicalInterpretation {
  final String category;
  final String title;
  final String severity;
  final String message;
  final List<String> evidence;

  const ClinicalInterpretation({
    required this.category,
    required this.title,
    required this.severity,
    required this.message,
    required this.evidence,
  });
}

class ScreeningFusionResult {
  final String riskBucket;
  final List<ScreeningAnalyteResult> analytes;
  final bool hasEvidenceConflict;
  final String? conflictTitle;
  final String? conflictMessage;
  final List<ClinicalInterpretation> interpretations;

  const ScreeningFusionResult({
    required this.riskBucket,
    required this.analytes,
    required this.interpretations,
    this.hasEvidenceConflict = false,
    this.conflictTitle,
    this.conflictMessage,
  });
}

class ScreeningFusionEngine {
  static List<ScreeningAnalyteResult> buildAnalytesFromRows(
    List<DipstickResultRow> rows,
  ) {
    ScreeningAnalyteResult resultFor(
      String code,
      String name, {
      required List<String> aliases,
    }) {
      final row = _findRow(rows, code, name, aliases);
      final display = row?.result ?? 'Unavailable';
      return ScreeningAnalyteResult(
        code: code,
        name: name,
        displayValue: display,
      );
    }

    return [
      resultFor('GLU', 'Glucose', aliases: const ['GLUCOSE']),
      resultFor('LEU', 'Leukocytes', aliases: const ['LEUKOCYTES']),
      resultFor('PRO', 'Protein', aliases: const ['PROTEIN']),
      resultFor('NIT', 'Nitrite', aliases: const ['NITRITE']),
    ];
  }

  static List<ScreeningAnalyteResult> get defaultAnalytes {
    return const [
      ScreeningAnalyteResult(
        code: 'GLU',
        name: 'Glucose',
        displayValue: 'Unavailable',
      ),
      ScreeningAnalyteResult(
        code: 'LEU',
        name: 'Leukocytes',
        displayValue: 'Unavailable',
      ),
      ScreeningAnalyteResult(
        code: 'PRO',
        name: 'Protein',
        displayValue: 'Unavailable',
      ),
      ScreeningAnalyteResult(
        code: 'NIT',
        name: 'Nitrite',
        displayValue: 'Unavailable',
      ),
    ];
  }

  const ScreeningFusionEngine();

  ScreeningFusionResult fuse({
    List<ScreeningAnalyteResult>? analytes,
    required ClinicalChecklistResult checklist,
  }) {
    final selectedAnalytes = analytes ?? defaultAnalytes;
    final interpretations = <ClinicalInterpretation>[
      _localizedUtiInterpretation(selectedAnalytes, checklist),
      _systemicUtiInterpretation(checklist),
      _renalFollowUpInterpretation(selectedAnalytes, checklist),
      _metabolicFollowUpInterpretation(selectedAnalytes),
    ];

    final priority = _reviewPriority(interpretations);
    final conflict = _evidenceConflict(interpretations, checklist);

    return ScreeningFusionResult(
      riskBucket: priority,
      analytes: selectedAnalytes,
      interpretations: interpretations,
      hasEvidenceConflict: conflict.title != null,
      conflictTitle: conflict.title,
      conflictMessage: conflict.message,
    );
  }

  ClinicalInterpretation _localizedUtiInterpretation(
    List<ScreeningAnalyteResult> analytes,
    ClinicalChecklistResult checklist,
  ) {
    final evidence = <String>[];
    final leukocytes = _byCode(analytes, 'LEU');
    final nitrite = _byCode(analytes, 'NIT');
    final leukocytesPositive = _isAbnormalDisplayValue(leukocytes?.displayValue);
    final nitritePositive = _isAbnormalDisplayValue(nitrite?.displayValue);

    if (leukocytesPositive) {
      evidence.add('Leukocyte esterase result: ${leukocytes!.displayValue}');
    }
    if (nitritePositive) {
      evidence.add('Nitrite result: ${nitrite!.displayValue}');
    }

    final dysuria = checklist.selectedSymptoms['dysuria'] == true;
    final frequency = checklist.selectedSymptoms['frequency'] == true;
    final urgency = checklist.selectedSymptoms['urgency'] == true;
    final hematuria = checklist.selectedSymptoms['hematuria'] == true;
    final suprapubic = checklist.selectedSymptoms['suprapubic'] == true;

    if (dysuria) evidence.add('Dysuria reported');
    if (frequency && urgency) {
      evidence.add('Frequency and urgency reported');
    } else if (frequency) {
      evidence.add('Frequency reported');
    } else if (urgency) {
      evidence.add('Urgency reported');
    }
    if (hematuria) evidence.add('Visible hematuria reported');
    if (suprapubic) {
      evidence.add('Lower abdominal pain reported; supporting symptom only');
    }

    final keySymptomCount = [dysuria, frequency, urgency, hematuria]
        .where((selected) => selected)
        .length;
    final hasDipstickUtiEvidence = leukocytesPositive || nitritePositive;
    final hasLocalizedEvidence = hasDipstickUtiEvidence || keySymptomCount >= 2;

    if (!hasLocalizedEvidence) {
      return ClinicalInterpretation(
        category: 'localized_uti',
        title: 'No localized UTI evidence detected',
        severity: 'low',
        message:
            'No nitrite/leukocyte signal and fewer than two supported urinary symptoms were identified.',
        evidence: evidence,
      );
    }

    return ClinicalInterpretation(
      category: 'localized_uti',
      title: 'Localized UTI findings detected',
      severity: nitritePositive || (hasDipstickUtiEvidence && keySymptomCount > 0)
          ? 'moderate'
          : 'caution',
      message:
          'Findings are consistent with possible localized UTI. Interpret with patient context and confirmatory testing when clinically needed.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _systemicUtiInterpretation(
    ClinicalChecklistResult checklist,
  ) {
    final evidence = <String>[];
    if (checklist.selectedSymptoms['fever'] == true) {
      evidence.add('Fever/chills reported');
    }
    if (checklist.selectedSymptoms['flank'] == true) {
      evidence.add('Back/flank pain reported');
    }
    if (checklist.selectedSymptoms['nausea'] == true) {
      evidence.add('Nausea/vomiting reported');
    }

    if (evidence.isEmpty) {
      return const ClinicalInterpretation(
        category: 'systemic_uti',
        title: 'No systemic UTI warning symptoms reported',
        severity: 'low',
        message:
            'No fever/chills, flank pain, or nausea/vomiting was selected.',
        evidence: [],
      );
    }

    return ClinicalInterpretation(
      category: 'systemic_uti',
      title: 'Systemic UTI warning symptoms reported',
      severity: 'high',
      message:
          'These symptoms are warning signs rather than validated multipliers in this app. Clinical review is recommended.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _renalFollowUpInterpretation(
    List<ScreeningAnalyteResult> analytes,
    ClinicalChecklistResult checklist,
  ) {
    final evidence = <String>[];
    final protein = _byCode(analytes, 'PRO');
    if (_isAbnormalDisplayValue(protein?.displayValue)) {
      evidence.add('Protein result: ${protein!.displayValue}');
    }
    if (checklist.selectedSymptoms['edema'] == true) {
      evidence.add('Peripheral edema reported');
    }

    if (evidence.isEmpty) {
      return const ClinicalInterpretation(
        category: 'renal_followup',
        title: 'No renal-related follow-up flag',
        severity: 'low',
        message:
            'No protein abnormality or edema follow-up indicator was identified.',
        evidence: [],
      );
    }

    return ClinicalInterpretation(
      category: 'renal_followup',
      title: 'Renal-related follow-up recommended',
      severity: 'moderate',
      message:
          'This is a follow-up flag, not a renal disease probability. Review clinically and confirm if persistent or clinically significant.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _metabolicFollowUpInterpretation(
    List<ScreeningAnalyteResult> analytes,
  ) {
    final glucose = _byCode(analytes, 'GLU');
    if (!_isAbnormalDisplayValue(glucose?.displayValue)) {
      return const ClinicalInterpretation(
        category: 'metabolic_followup',
        title: 'No metabolic follow-up flag',
        severity: 'low',
        message: 'No glucose abnormality was identified by the dipstick scan.',
        evidence: [],
      );
    }

    return ClinicalInterpretation(
      category: 'metabolic_followup',
      title: 'Metabolic follow-up recommended',
      severity: 'moderate',
      message:
          'Glucose abnormality is handled separately from UTI evidence and should not be averaged into a UTI probability.',
      evidence: ['Glucose result: ${glucose!.displayValue}'],
    );
  }

  String _reviewPriority(List<ClinicalInterpretation> interpretations) {
    if (interpretations.any((item) => item.severity == 'high')) {
      return 'High';
    }
    if (interpretations.any((item) => item.severity == 'moderate')) {
      return 'Moderate';
    }
    if (interpretations.any((item) => item.severity == 'caution')) {
      return 'Caution';
    }
    return 'Low';
  }

  _EvidenceConflict _evidenceConflict(
    List<ClinicalInterpretation> interpretations,
    ClinicalChecklistResult checklist,
  ) {
    final localized = interpretations.firstWhere(
      (item) => item.category == 'localized_uti',
    );
    final selectedSymptoms = checklist.selectedSymptoms.values
        .where((selected) => selected)
        .length;
    if (localized.severity != 'low' && selectedSymptoms == 0) {
      return const _EvidenceConflict(
        title: 'Dipstick finding without reported symptoms',
        message:
            'Abnormal UTI-related dipstick evidence was detected despite no selected symptoms. Repeat scanning or professional review is recommended.',
      );
    }
    return const _EvidenceConflict();
  }

  static ScreeningAnalyteResult? _byCode(
    List<ScreeningAnalyteResult> analytes,
    String code,
  ) {
    for (final item in analytes) {
      if (item.code == code) return item;
    }
    return null;
  }

  static DipstickResultRow? _findRow(
    List<DipstickResultRow> rows,
    String code,
    String name,
    List<String> aliases,
  ) {
    final acceptedCodes = {
      code.toUpperCase(),
      name.toUpperCase(),
      ...aliases.map((item) => item.toUpperCase()),
    };
    final acceptedNames = {
      name.toUpperCase(),
      ...aliases.map((item) => item.toUpperCase()),
    };

    for (final row in rows) {
      final rowCode = row.code.trim().toUpperCase();
      final rowName = row.name.trim().toUpperCase();
      if (acceptedCodes.contains(rowCode) || acceptedNames.contains(rowName)) {
        return row;
      }
    }
    return null;
  }

  static bool _isAbnormalDisplayValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unavailable') {
      return false;
    }
    return !(normalized == 'neg' || normalized == 'negative');
  }
}

class _EvidenceConflict {
  final String? title;
  final String? message;

  const _EvidenceConflict({this.title, this.message});
}
