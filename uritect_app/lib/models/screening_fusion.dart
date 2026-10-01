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

class BayesianEvidenceFactor {
  final String group;
  final String finding;
  final double likelihoodRatio;
  final String source;

  const BayesianEvidenceFactor({
    required this.group,
    required this.finding,
    required this.likelihoodRatio,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'group': group,
    'finding': finding,
    'likelihoodRatio': likelihoodRatio,
    'source': source,
  };

  factory BayesianEvidenceFactor.fromJson(Map<String, dynamic> json) {
    return BayesianEvidenceFactor(
      group: json['group'] as String? ?? 'Unknown',
      finding: json['finding'] as String? ?? 'Unknown evidence',
      likelihoodRatio: (json['likelihoodRatio'] as num?)?.toDouble() ?? 1.0,
      source: json['source'] as String? ?? 'Unavailable',
    );
  }
}

class BayesianUtiEstimate {
  final String modelVersion;
  final double priorProbability;
  final double posteriorProbability;
  final String calculationStatus;
  final String statusReason;
  final List<BayesianEvidenceFactor> factors;

  bool get isCalculable => calculationStatus == 'calculated';
  double get posteriorPercent => posteriorProbability * 100;

  const BayesianUtiEstimate({
    required this.modelVersion,
    required this.priorProbability,
    required this.posteriorProbability,
    required this.calculationStatus,
    required this.statusReason,
    required this.factors,
  });
}

class ScreeningFusionResult {
  final String clinicalAction;
  final List<ScreeningAnalyteResult> analytes;
  final bool hasEvidenceConflict;
  final String? conflictTitle;
  final String? conflictMessage;
  final List<ClinicalInterpretation> interpretations;
  final BayesianUtiEstimate utiEstimate;

  const ScreeningFusionResult({
    required this.clinicalAction,
    required this.analytes,
    required this.interpretations,
    required this.utiEstimate,
    this.hasEvidenceConflict = false,
    this.conflictTitle,
    this.conflictMessage,
  });

  // Kept only for reading code that still uses the legacy persistence name.
  String get riskBucket => clinicalAction;
}

class ScreeningFusionEngine {
  static const String femaleModelVersion = 'uti_bayesian_female_v1_1_20260926';
  static const String maleModelVersion = 'uti_bayesian_male_v0_1_20261001';
  static const String bayesianModelVersion = femaleModelVersion;
  static const double femalePriorProbability = 0.50;
  static const double malePriorProbability = 97 / 186;
  static const double priorProbability = femalePriorProbability;
  static const List<String> commonEligibilityConfirmations = [
    'uti_eligible_age_18_64',
    'uti_eligible_no_catheter',
    'uti_eligible_no_urologic_abnormality',
    'uti_eligible_not_immunocompromised',
  ];
  static const List<String> femaleEligibilityConfirmations = [
    ...commonEligibilityConfirmations,
    'uti_eligible_nonpregnant',
  ];
  static const List<String> maleEligibilityConfirmations = [
    ...commonEligibilityConfirmations,
    'uti_male_no_diabetes',
    'uti_male_no_suspected_sti',
  ];
  // Retained for older tests and records that mean the female v1.1 gate.
  static const List<String> eligibilityConfirmations = [
    'uti_eligible_female',
    ...femaleEligibilityConfirmations,
  ];

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
      resultFor('LEU', 'Leukocytes', aliases: const ['LEUKOCYTES']),
      resultFor('NIT', 'Nitrite', aliases: const ['NITRITE']),
      resultFor('BLD', 'Blood', aliases: const ['BLOOD']),
    ];
  }

  static List<ScreeningAnalyteResult> get defaultAnalytes {
    return const [
      ScreeningAnalyteResult(
        code: 'LEU',
        name: 'Leukocytes',
        displayValue: 'Unavailable',
      ),
      ScreeningAnalyteResult(
        code: 'NIT',
        name: 'Nitrite',
        displayValue: 'Unavailable',
      ),
      ScreeningAnalyteResult(
        code: 'BLD',
        name: 'Blood',
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
    final utiEstimate = _calculateBayesianUtiEstimate(
      selectedAnalytes,
      checklist,
    );
    final interpretations = <ClinicalInterpretation>[
      _utiScreeningInterpretation(utiEstimate),
      _alternateCauseInterpretation(checklist),
      _visibleHematuriaInterpretation(checklist),
      _systemicWarningInterpretation(checklist),
    ];

    final clinicalAction = _clinicalAction(interpretations, utiEstimate);
    final conflict = _evidenceConflict(selectedAnalytes, checklist);

    return ScreeningFusionResult(
      clinicalAction: clinicalAction,
      analytes: selectedAnalytes,
      interpretations: interpretations,
      utiEstimate: utiEstimate,
      hasEvidenceConflict: conflict.title != null,
      conflictTitle: conflict.title,
      conflictMessage: conflict.message,
    );
  }

  BayesianUtiEstimate _calculateBayesianUtiEstimate(
    List<ScreeningAnalyteResult> analytes,
    ClinicalChecklistResult checklist,
  ) {
    final factors = <BayesianEvidenceFactor>[];
    final female = checklist.selectedSymptoms['uti_eligible_female'] == true;
    final male = checklist.selectedSymptoms['uti_eligible_male'] == true;
    final sexIsValid = female != male;
    final requiredEligibility = female
        ? femaleEligibilityConfirmations
        : male
        ? maleEligibilityConfirmations
        : const <String>[];
    final missingEligibility = requiredEligibility
        .where((id) => checklist.selectedSymptoms[id] != true)
        .toList();
    final hasFemaleUrinarySymptom = const [
      'dysuria',
      'frequency',
      'urgency',
      'suprapubic',
      'hematuria',
    ].any((id) => checklist.selectedSymptoms[id] == true);
    final hasMaleUrinarySymptom = const [
      'dysuria',
      'frequency',
      'urgency',
    ].any((id) => checklist.selectedSymptoms[id] == true);
    final hasUrinarySymptom = female
        ? hasFemaleUrinarySymptom
        : hasMaleUrinarySymptom;
    final hasAlternateCause =
        checklist.selectedSymptoms['vaginal_discharge'] == true ||
        checklist.selectedSymptoms['vaginal_irritation'] == true;
    final hasSystemicFinding =
        checklist.selectedSymptoms['fever'] == true ||
        checklist.selectedSymptoms['flank'] == true ||
        checklist.selectedSymptoms['nausea'] == true;

    String? blockedReason;
    if (!sexIsValid) {
      blockedReason = 'Select exactly one sex for the sex-specific UTI model.';
    } else if (missingEligibility.isNotEmpty) {
      blockedReason =
          'The intended-population eligibility confirmations are incomplete.';
    } else if (!hasUrinarySymptom) {
      blockedReason = 'No acute urinary symptom was reported.';
    } else if (hasAlternateCause) {
      blockedReason =
          'Vaginal discharge or irritation requires the alternate-cause consultation pathway.';
    } else if (hasSystemicFinding) {
      blockedReason =
          'A systemic warning finding requires consultation outside the uncomplicated lower-UTI pathway.';
    }

    if (blockedReason != null) {
      return BayesianUtiEstimate(
        modelVersion: female
            ? femaleModelVersion
            : male
            ? maleModelVersion
            : 'uti_bayesian_sex_specific_not_selected',
        priorProbability: female
            ? femalePriorProbability
            : male
            ? malePriorProbability
            : 0,
        posteriorProbability: 0,
        calculationStatus: 'not_designed',
        statusReason: blockedReason,
        factors: const [],
      );
    }

    final leukocytes = _byCode(analytes, 'LEU');
    final nitrite = _byCode(analytes, 'NIT');
    final blood = _byCode(analytes, 'BLD');
    final leukocytesPositive = _isLeukocyteStudyPositive(
      leukocytes?.displayValue,
    );
    final nitritePositive = _isNitriteStudyPositive(nitrite?.displayValue);
    final bloodPositive = _isBloodStudyPositive(blood?.displayValue);
    final leukocytesNegative = _isNegative(leukocytes?.displayValue);
    final nitriteNegative = _isNegative(nitrite?.displayValue);
    final bloodNegative = _isNegative(blood?.displayValue);

    if (male) {
      final maleLeukocytesPositive = _isMaleLeukocytePositive(
        leukocytes?.displayValue,
      );
      // Ordered male thresholds are taken from den Heijer et al. (2012),
      // Table 2. One factor only is used, so correlated dipstick thresholds
      // are never multiplied as independent evidence.
      if (nitritePositive && maleLeukocytesPositive) {
        factors.add(
          const BayesianEvidenceFactor(
            group: 'Male dipstick threshold',
            finding: 'Nitrite and leukocyte esterase positive',
            likelihoodRatio: 5.14,
            source: 'den Heijer et al. 2012, Table 2',
          ),
        );
      } else if (nitritePositive) {
        factors.add(
          const BayesianEvidenceFactor(
            group: 'Male dipstick threshold',
            finding: 'Nitrite-positive threshold met',
            likelihoodRatio: 4.87,
            source: 'den Heijer et al. 2012, Table 2',
          ),
        );
      } else if (maleLeukocytesPositive) {
        factors.add(
          const BayesianEvidenceFactor(
            group: 'Male dipstick threshold',
            finding: 'Leukocyte-esterase-positive threshold met',
            likelihoodRatio: 1.65,
            source: 'den Heijer et al. 2012, Table 2',
          ),
        );
      } else if (nitriteNegative && leukocytesNegative) {
        factors.add(
          const BayesianEvidenceFactor(
            group: 'Male dipstick threshold',
            finding: 'Nitrite and leukocyte esterase both negative',
            likelihoodRatio: 0.35,
            source: 'den Heijer et al. 2012, Table 2',
          ),
        );
      }

      var odds = malePriorProbability / (1 - malePriorProbability);
      for (final factor in factors) {
        odds *= factor.likelihoodRatio;
      }
      final posterior = odds / (1 + odds);
      return BayesianUtiEstimate(
        modelVersion: maleModelVersion,
        priorProbability: malePriorProbability,
        posteriorProbability: posterior,
        calculationStatus: factors.isEmpty ? 'insufficient' : 'calculated',
        statusReason: factors.isEmpty
            ? 'No source-matched male nitrite/leukocyte threshold was available.'
            : 'Calculated with the provisional male ordered-threshold model; not locally calibrated.',
        factors: factors,
      );
    }

    // One mutually exclusive dipstick factor prevents multiplying correlated
    // nitrite, leukocyte esterase, and blood results as independent tests.
    if (nitritePositive && (leukocytesPositive || bloodPositive)) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Dipstick',
          finding: 'Nitrite plus leukocytes or blood positive',
          likelihoodRatio: 7.2,
          source: 'Little et al. 2006/2009',
        ),
      );
    } else if (nitritePositive) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Dipstick',
          finding: 'Nitrite positive',
          likelihoodRatio: 5.5,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    } else if (leukocytesPositive || bloodPositive) {
      final useBlood = bloodPositive;
      factors.add(
        BayesianEvidenceFactor(
          group: 'Dipstick',
          finding: useBlood ? 'Blood positive' : 'Leukocytes positive',
          likelihoodRatio: useBlood ? 1.7 : 1.4,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    } else if (leukocytesNegative && nitriteNegative && bloodNegative) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Dipstick',
          finding: 'Nitrite, leukocytes, and blood all negative',
          likelihoodRatio: 0.22,
          source: 'Little et al. 2006/2009',
        ),
      );
    }

    final dysuria = checklist.selectedSymptoms['dysuria'] == true;
    final frequency = checklist.selectedSymptoms['frequency'] == true;
    final urgency = checklist.selectedSymptoms['urgency'] == true;
    // Use only the strongest supported urinary-symptom factor. This avoids
    // treating overlapping urinary symptoms as conditionally independent.
    if (dysuria && urgency) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Urinary symptoms',
          finding: 'Urgency with dysuria reported',
          likelihoodRatio: 1.5,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    } else if (dysuria) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Urinary symptoms',
          finding: 'Dysuria reported',
          likelihoodRatio: 1.3,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    } else if (urgency) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Urinary symptoms',
          finding: 'Urgency reported',
          likelihoodRatio: 1.2,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    } else if (frequency) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Urinary symptoms',
          finding: 'Frequency reported',
          likelihoodRatio: 1.1,
          source: 'Kurotschka et al. 2024, Table 4',
        ),
      );
    }

    var odds = femalePriorProbability / (1 - femalePriorProbability);
    for (final factor in factors) {
      odds *= factor.likelihoodRatio;
    }
    final posterior = odds / (1 + odds);

    return BayesianUtiEstimate(
      modelVersion: femaleModelVersion,
      priorProbability: femalePriorProbability,
      posteriorProbability: posterior,
      calculationStatus: factors.isEmpty ? 'insufficient' : 'calculated',
      statusReason: factors.isEmpty
          ? 'No source-matched dipstick category or weighted urinary symptom was available.'
          : 'Calculated for the confirmed intended population using the provisional grouped-LR model.',
      factors: factors,
    );
  }

  ClinicalInterpretation _utiScreeningInterpretation(
    BayesianUtiEstimate estimate,
  ) {
    final evidence = estimate.factors
        .map(
          (factor) =>
              '${factor.finding} (LR ${factor.likelihoodRatio.toStringAsFixed(2)})',
        )
        .toList();
    if (!estimate.isCalculable) {
      return ClinicalInterpretation(
        category: 'uti_screening',
        title: estimate.calculationStatus == 'not_designed'
            ? 'UTI estimate not designed for this situation'
            : 'Insufficient evidence for UTI estimate',
        severity: estimate.calculationStatus == 'not_designed'
            ? 'caution'
            : 'low',
        message: estimate.calculationStatus == 'not_designed'
            ? '${estimate.statusReason} Consultation with a healthcare professional is suggested.'
            : '${estimate.statusReason} The starting prior is not displayed as a patient result.',
        evidence: const [],
      );
    }

    return ClinicalInterpretation(
      category: 'uti_screening',
      title: 'UTI screening estimate calculated',
      severity: 'low',
      message:
          'The sex-specific Bayesian research estimate is shown with the evidence factor used. It supports screening only and is not a diagnosis or treatment recommendation.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _alternateCauseInterpretation(
    ClinicalChecklistResult checklist,
  ) {
    final evidence = <String>[];
    if (checklist.selectedSymptoms['vaginal_discharge'] == true) {
      evidence.add('Vaginal discharge reported');
    }
    if (checklist.selectedSymptoms['vaginal_irritation'] == true) {
      evidence.add('Vaginal irritation reported');
    }

    if (evidence.isEmpty) {
      return const ClinicalInterpretation(
        category: 'alternate_cause',
        title: 'No alternate-cause symptom reported',
        severity: 'low',
        message:
            'No vaginal discharge or irritation was selected in the checklist.',
        evidence: [],
      );
    }

    return ClinicalInterpretation(
      category: 'alternate_cause',
      title: 'Alternate-cause symptoms reported',
      severity: 'caution',
      message:
          'Other conditions may cause similar symptoms. Consultation with a healthcare professional is suggested. No ordinary lower-UTI posterior was calculated.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _systemicWarningInterpretation(
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
    if (checklist.selectedSymptoms['cannot_hydrate_or_medicate'] == true) {
      evidence.add('Vomiting prevents hydration or oral medication');
    }
    if (checklist.selectedSymptoms['confusion_fainting_weakness'] == true) {
      evidence.add('Confusion, fainting, or severe weakness reported');
    }

    final fever = checklist.selectedSymptoms['fever'] == true;
    final flank = checklist.selectedSymptoms['flank'] == true;
    final nausea = checklist.selectedSymptoms['nausea'] == true;
    final cannotHydrate =
        checklist.selectedSymptoms['cannot_hydrate_or_medicate'] == true;
    final seriousIllness =
        checklist.selectedSymptoms['confusion_fainting_weakness'] == true;
    final urinaryFinding = const [
      'dysuria',
      'frequency',
      'urgency',
      'suprapubic',
      'hematuria',
    ].any((id) => checklist.selectedSymptoms[id] == true);
    final prompt =
        (fever && flank) ||
        (nausea && (fever || flank)) ||
        cannotHydrate ||
        (seriousIllness && urinaryFinding);

    if (evidence.isEmpty && !cannotHydrate && !seriousIllness) {
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
      title: prompt
          ? 'Prompt medical consultation suggested'
          : 'Systemic symptom requires consultation',
      severity: prompt ? 'high' : 'caution',
      message: prompt
          ? 'This combination may indicate serious illness, upper UTI, dehydration risk, or a complicated condition. Prompt medical consultation is suggested.'
          : 'This finding is outside the ordinary lower-UTI estimate. Consultation with a healthcare professional is suggested.',
      evidence: evidence,
    );
  }

  ClinicalInterpretation _visibleHematuriaInterpretation(
    ClinicalChecklistResult checklist,
  ) {
    final reported = checklist.selectedSymptoms['hematuria'] == true;
    return ClinicalInterpretation(
      category: 'visible_hematuria',
      title: reported
          ? 'Visible hematuria reported'
          : 'No visible hematuria reported',
      severity: reported ? 'caution' : 'low',
      message: reported
          ? 'Consultation with a healthcare professional is suggested. This finding is recorded as context and is not numerically weighted when dipstick blood can contribute.'
          : 'Visible hematuria was not selected. An unchecked item is treated as unknown, not confirmed absent.',
      evidence: reported ? const ['Visible hematuria reported'] : const [],
    );
  }

  String _clinicalAction(
    List<ClinicalInterpretation> interpretations,
    BayesianUtiEstimate estimate,
  ) {
    if (interpretations.any((item) => item.severity == 'high')) {
      return 'Prompt medical consultation suggested';
    }
    if (interpretations.any(
      (item) => item.severity == 'moderate' || item.severity == 'caution',
    )) {
      return 'Consultation suggested';
    }
    if (estimate.calculationStatus == 'insufficient') {
      return 'Insufficient evidence';
    }
    if (estimate.factors.any((factor) => factor.likelihoodRatio > 1.0)) {
      return 'Consultation suggested';
    }
    return 'Observe for symptoms';
  }

  _EvidenceConflict _evidenceConflict(
    List<ScreeningAnalyteResult> analytes,
    ClinicalChecklistResult checklist,
  ) {
    final hasAbnormalDipstick = analytes.any(
      (item) => _isAbnormalDisplayValue(item.displayValue),
    );
    final selectedSymptoms = const [
      'dysuria',
      'frequency',
      'urgency',
      'suprapubic',
      'hematuria',
      'vaginal_discharge',
      'vaginal_irritation',
      'flank',
      'fever',
      'nausea',
    ].where((id) => checklist.selectedSymptoms[id] == true).length;
    if (hasAbnormalDipstick && selectedSymptoms == 0) {
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

  static bool _isNegative(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'neg' || normalized == 'negative';
  }

  static bool _isNitriteStudyPositive(String? value) {
    return (value ?? '').trim().toLowerCase() == 'positive';
  }

  static bool _isLeukocyteStudyPositive(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'small 70' ||
        normalized == 'moderate 125' ||
        normalized == 'large 500' ||
        normalized == '+' ||
        normalized == '++' ||
        normalized == '+++';
  }

  static bool _isMaleLeukocytePositive(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'trace 15' ||
        normalized == 'trace' ||
        _isLeukocyteStudyPositive(value);
  }

  static bool _isBloodStudyPositive(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == 'hemolyzed 10' ||
        normalized == 'small 25' ||
        normalized == 'moderate 80' ||
        normalized == 'large 200';
  }
}

class _EvidenceConflict {
  final String? title;
  final String? message;

  const _EvidenceConflict({this.title, this.message});
}
