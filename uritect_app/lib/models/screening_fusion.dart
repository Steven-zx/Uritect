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

  const ScreeningFusionResult({
    required this.posteriorProbability,
    required this.riskBucket,
    required this.analytes,
    required this.logOddsContribution,
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

  static List<ScreeningAnalyteResult> buildAnalytesFromProbabilities(Map<String, double> probabilities) {
    double p(String code, double fallback) => probabilities[code]?.clamp(0.0, 1.0) ?? fallback;

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
    final padAbnormalProbability = selectedAnalytes
        .map((item) => _clipProbability(item.abnormalProbability))
        .reduce((a, b) => a + b) /
        selectedAnalytes.length;
    logOdds += _logOddsFromProbability(padAbnormalProbability);

    // Clinical symptom contribution via Bayesian LR
    final clinicalLogOdds = checklist.computeLogOddsContribution();
    logOdds += clinicalLogOdds;

    final posterior = _clipProbability(_posteriorFromLogOdds(logOdds));
    final bucket = posterior < 0.35
        ? 'Low'
        : posterior <= 0.70
            ? 'Moderate'
            : 'High';

    return ScreeningFusionResult(
      posteriorProbability: posterior,
      riskBucket: bucket,
      analytes: selectedAnalytes,
      logOddsContribution: clinicalLogOdds,
    );
  }
}