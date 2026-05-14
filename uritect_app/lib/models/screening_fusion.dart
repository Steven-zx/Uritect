import 'dart:math';
import 'knn_probabilities.dart';
import 'clinical_symptoms.dart';

class ScreeningAnalyteResult {
  final String code;
  final String name;
  final double abnormalProbability;
  final String displayValue;

  const ScreeningAnalyteResult({
    required this.code,
    required this.name,
    required this.abnormalProbability,
    required this.displayValue,
  });
}

class ScreeningFusionResult {
  final double posteriorProbability;
  final String riskBucket;
  final List<ScreeningAnalyteResult> analytes;
  final double logOddsContribution; // From clinical symptoms
  final bool hasEvidenceConflict;
  final String? conflictTitle;
  final String? conflictMessage;

  const ScreeningFusionResult({
    required this.posteriorProbability,
    required this.riskBucket,
    required this.analytes,
    required this.logOddsContribution,
    this.hasEvidenceConflict = false,
    this.conflictTitle,
    this.conflictMessage,
  });
}

class ScreeningFusionEngine {
  static String displayValueForProbability(double probability) {
    if (probability < 0.25) {
      return 'Negative';
    }
    if (probability < 0.50) {
      return 'Trace';
    }
    if (probability < 0.75) {
      return 'Moderate';
    }
    return 'High';
  }

  static List<ScreeningAnalyteResult> buildAnalytesFromProbabilities(
    Map<String, double> probabilities,
  ) {
    double p(String code, double fallback) =>
        probabilities[code]?.clamp(0.0, 1.0) ?? fallback;

    return [
      ScreeningAnalyteResult(
        code: 'GLU',
        name: 'Glucose',
        abnormalProbability: p('GLU', 0.10),
        displayValue: displayValueForProbability(p('GLU', 0.10)),
      ),
      ScreeningAnalyteResult(
        code: 'LEU',
        name: 'Leukocytes',
        abnormalProbability: p('LEU', 0.66),
        displayValue: displayValueForProbability(p('LEU', 0.66)),
      ),
      ScreeningAnalyteResult(
        code: 'PRO',
        name: 'Protein',
        abnormalProbability: p('PRO', 0.14),
        displayValue: displayValueForProbability(p('PRO', 0.14)),
      ),
      ScreeningAnalyteResult(
        code: 'NIT',
        name: 'Nitrite',
        abnormalProbability: p('NIT', 0.12),
        displayValue: displayValueForProbability(p('NIT', 0.12)),
      ),
    ];
  }

  static List<ScreeningAnalyteResult> get defaultAnalytes {
    return buildAnalytesFromProbabilities(knnProbabilities);
  }

  final double priorAbnormal;

  const ScreeningFusionEngine({this.priorAbnormal = 0.5});

  double _clipProbability(double probability) {
    return min(max(probability, 1e-6), 1.0 - 1e-6);
  }

  double _logOddsFromProbability(double probability) {
    final clipped = _clipProbability(probability);
    return log(clipped / (1.0 - clipped));
  }

  double _posteriorFromLogOdds(double logOdds) {
    return 1.0 / (1.0 + exp(-logOdds));
  }

  ScreeningFusionResult fuse({
    List<ScreeningAnalyteResult>? analytes,
    required ClinicalChecklistResult checklist,
  }) {
    final selectedAnalytes = analytes ?? defaultAnalytes;
    if (selectedAnalytes.length != 4) {
      throw ArgumentError('Screening fusion expects exactly 4 analytes.');
    }

    var logOdds = _logOddsFromProbability(priorAbnormal);

    // Pad abnormal probability signal
    final padAbnormalProbability =
        selectedAnalytes
            .map((item) => _clipProbability(item.abnormalProbability))
            .reduce((a, b) => a + b) /
        selectedAnalytes.length;
    logOdds += _logOddsFromProbability(padAbnormalProbability);

    // Clinical symptom contribution via Bayesian LR
    final clinicalLogOdds = checklist.computeLogOddsContribution();
    logOdds += clinicalLogOdds;

    final symptomCount = checklist.selectedSymptoms.values
        .where((v) => v)
        .length;
    final renalSymptomCount = clinicalSymptoms
        .where((symptom) => symptom.category == 'renal')
        .where((symptom) => checklist.selectedSymptoms[symptom.id] == true)
        .length;

    final fusedPosterior = _clipProbability(_posteriorFromLogOdds(logOdds));
    final conflict = _assessEvidenceConflict(
      padAbnormalProbability: padAbnormalProbability,
      symptomCount: symptomCount,
      renalSymptomCount: renalSymptomCount,
    );
    final posterior = _clipProbability(
      max(fusedPosterior, conflict.minimumPosterior),
    );
    final bucket = posterior < 0.30
        ? 'Low'
        : posterior <= 0.70
        ? 'Moderate'
        : 'High';

    return ScreeningFusionResult(
      posteriorProbability: posterior,
      riskBucket: bucket,
      analytes: selectedAnalytes,
      logOddsContribution: clinicalLogOdds,
      hasEvidenceConflict: conflict.hasConflict,
      conflictTitle: conflict.title,
      conflictMessage: conflict.message,
    );
  }

  _EvidenceConflict _assessEvidenceConflict({
    required double padAbnormalProbability,
    required int symptomCount,
    required int renalSymptomCount,
  }) {
    if (padAbnormalProbability >= 0.45 && symptomCount == 0) {
      return const _EvidenceConflict(
        hasConflict: true,
        title: 'Dipstick finding without reported symptoms',
        message:
            'The dipstick scan shows an objective abnormal signal, but the checklist has no reported symptoms. Keep the dipstick result as the primary finding and consider repeating the scan or reviewing the patient context.',
        minimumPosterior: 0.45,
      );
    }

    if (padAbnormalProbability < 0.30 && symptomCount >= 2) {
      return _EvidenceConflict(
        hasConflict: true,
        title: 'Symptoms reported despite low dipstick signal',
        message: renalSymptomCount > 0
            ? 'The dipstick scan is low, but the checklist includes upper urinary tract symptoms. Review clinically and consider repeat testing if symptoms persist.'
            : 'The dipstick scan is low, but multiple symptoms were reported. Treat this as a caution result rather than a fully negative screen.',
        minimumPosterior: renalSymptomCount > 0 ? 0.45 : 0.30,
      );
    }

    return const _EvidenceConflict();
  }
}

class _EvidenceConflict {
  final bool hasConflict;
  final String? title;
  final String? message;
  final double minimumPosterior;

  const _EvidenceConflict({
    this.hasConflict = false,
    this.title,
    this.message,
    this.minimumPosterior = 0.0,
  });
}
