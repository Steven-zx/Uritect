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
}

class BayesianUtiEstimate {
  final String modelVersion;
  final double priorProbability;
  final double posteriorProbability;
  final String likelihoodBand;
  final List<BayesianEvidenceFactor> factors;

  bool get isCalculable => factors.isNotEmpty;

  const BayesianUtiEstimate({
    required this.modelVersion,
    required this.priorProbability,
    required this.posteriorProbability,
    required this.likelihoodBand,
    required this.factors,
  });
}

class ScreeningFusionResult {
  final String riskBucket;
  final List<ScreeningAnalyteResult> analytes;
  final bool hasEvidenceConflict;
  final String? conflictTitle;
  final String? conflictMessage;
  final List<ClinicalInterpretation> interpretations;
  final BayesianUtiEstimate utiEstimate;

  const ScreeningFusionResult({
    required this.riskBucket,
    required this.analytes,
    required this.interpretations,
    required this.utiEstimate,
    this.hasEvidenceConflict = false,
    this.conflictTitle,
    this.conflictMessage,
  });
}

class ScreeningFusionEngine {
  static const String bayesianModelVersion =
      'uti_bayesian_lr_candidate_v1_20260917';
  static const double priorProbability = 0.50;
  static const double lowerLikelihoodThreshold = 0.20;
  static const double higherLikelihoodThreshold = 0.80;

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
      _systemicWarningInterpretation(checklist),
    ];

    final priority = _reviewPriority(interpretations);
    final conflict = _evidenceConflict(selectedAnalytes, checklist);

    return ScreeningFusionResult(
      riskBucket: priority,
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
    final leukocytes = _byCode(analytes, 'LEU');
    final nitrite = _byCode(analytes, 'NIT');
    final blood = _byCode(analytes, 'BLD');
    final leukocytesPositive = _isAbnormalDisplayValue(
      leukocytes?.displayValue,
    );
    final nitritePositive = _isAbnormalDisplayValue(nitrite?.displayValue);
    final bloodPositive = _isAbnormalDisplayValue(blood?.displayValue);
    final leukocytesKnown = _isKnownDisplayValue(leukocytes?.displayValue);
    final nitriteKnown = _isKnownDisplayValue(nitrite?.displayValue);
    final bloodKnown = _isKnownDisplayValue(blood?.displayValue);

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
    } else if (leukocytesKnown && nitriteKnown && bloodKnown) {
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
    final hematuria = checklist.selectedSymptoms['hematuria'] == true;
    // Use only the strongest supported urinary-symptom factor. This avoids
    // treating overlapping urinary symptoms as conditionally independent.
    if (hematuria) {
      factors.add(
        const BayesianEvidenceFactor(
          group: 'Urinary symptoms',
          finding: 'Visible hematuria reported',
          likelihoodRatio: 2.0,
          source: 'Bent et al. 2002',
        ),
      );
    } else if (dysuria && urgency) {
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

    final discharge = checklist.selectedSymptoms['vaginal_discharge'] == true;
    final irritation = checklist.selectedSymptoms['vaginal_irritation'] == true;
    if (irritation || discharge) {
      factors.add(
        BayesianEvidenceFactor(
          group: 'Alternate-cause symptoms',
          finding: irritation
              ? 'Vaginal irritation reported'
              : 'Vaginal discharge reported',
          likelihoodRatio: irritation ? 0.2 : 0.3,
          source: 'Bent et al. 2002',
        ),
      );
    }

    var odds = priorProbability / (1 - priorProbability);
    for (final factor in factors) {
      odds *= factor.likelihoodRatio;
    }
    final posterior = odds / (1 + odds);
    final band = factors.isEmpty
        ? 'Insufficient'
        : posterior < lowerLikelihoodThreshold
        ? 'Lower'
        : posterior >= higherLikelihoodThreshold
        ? 'Higher'
        : 'Intermediate';

    return BayesianUtiEstimate(
      modelVersion: bayesianModelVersion,
      priorProbability: priorProbability,
      posteriorProbability: posterior,
      likelihoodBand: band,
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
    final percent = (estimate.posteriorProbability * 100).toStringAsFixed(1);

    if (!estimate.isCalculable) {
      return const ClinicalInterpretation(
        category: 'uti_screening',
        title: 'Insufficient evidence for UTI estimate',
        severity: 'low',
        message:
            'No usable UTI-related dipstick result or supported weighted symptom was available.',
        evidence: [],
      );
    }

    return ClinicalInterpretation(
      category: 'uti_screening',
      title: '${estimate.likelihoodBand} estimated UTI likelihood',
      severity: estimate.likelihoodBand == 'Higher'
          ? 'moderate'
          : estimate.likelihoodBand == 'Intermediate'
          ? 'caution'
          : 'low',
      message:
          'Candidate Bayesian estimate: $percent%. Intended for nonpregnant adult women with urinary symptoms; not a diagnosis and not clinically validated yet.',
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
          'These symptoms can lower the likelihood of uncomplicated UTI and may suggest another cause that needs clinical review.',
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
          'These symptoms may suggest upper UTI, pyelonephritis, or complicated infection. Clinical review is recommended.',
      evidence: evidence,
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
    List<ScreeningAnalyteResult> analytes,
    ClinicalChecklistResult checklist,
  ) {
    final hasAbnormalDipstick = analytes.any(
      (item) => _isAbnormalDisplayValue(item.displayValue),
    );
    final selectedSymptoms = checklist.selectedSymptoms.values
        .where((selected) => selected)
        .length;
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

  static bool _isKnownDisplayValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'unavailable';
  }
}

class _EvidenceConflict {
  final String? title;
  final String? message;

  const _EvidenceConflict({this.title, this.message});
}
