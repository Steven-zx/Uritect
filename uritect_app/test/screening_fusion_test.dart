import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/screening_fusion.dart';

void main() {
  const engine = ScreeningFusionEngine();

  ClinicalChecklistResult checklist(List<String> selected) {
    return ClinicalChecklistResult(
      selectedSymptoms: {
        for (final symptom in clinicalSymptoms)
          symptom.id: selected.contains(symptom.id),
      },
    );
  }

  List<ScreeningAnalyteResult> analytes({
    String leukocytes = 'Negative',
    String nitrite = 'Negative',
    String blood = 'Negative',
  }) {
    return [
      ScreeningAnalyteResult(
        code: 'LEU',
        name: 'Leukocytes',
        displayValue: leukocytes,
      ),
      ScreeningAnalyteResult(
        code: 'NIT',
        name: 'Nitrite',
        displayValue: nitrite,
      ),
      ScreeningAnalyteResult(code: 'BLD', name: 'Blood', displayValue: blood),
    ];
  }

  test('all-negative dipstick applies the validated grouped negative LR', () {
    final result = engine.fuse(
      analytes: analytes(),
      checklist: checklist(const []),
    );

    expect(result.utiEstimate.factors, hasLength(1));
    expect(result.utiEstimate.factors.single.likelihoodRatio, 0.22);
    expect(result.utiEstimate.posteriorProbability, closeTo(0.1803, 0.0001));
    expect(result.utiEstimate.likelihoodBand, 'Lower');
  });

  test('correlated positive dipsticks use one grouped LR', () {
    final result = engine.fuse(
      analytes: analytes(leukocytes: 'Moderate', nitrite: 'Positive'),
      checklist: checklist(const ['dysuria', 'urgency']),
    );

    expect(result.utiEstimate.factors, hasLength(2));
    expect(result.utiEstimate.factors[0].likelihoodRatio, 7.2);
    expect(result.utiEstimate.factors[1].likelihoodRatio, 1.5);
    expect(result.utiEstimate.posteriorProbability, closeTo(0.9153, 0.0001));
    expect(result.utiEstimate.likelihoodBand, 'Higher');
  });

  test('vaginal irritation lowers rather than raises the estimate', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const ['dysuria', 'vaginal_irritation']),
    );

    expect(result.utiEstimate.posteriorProbability, closeTo(0.5885, 0.0001));
    expect(result.utiEstimate.factors.last.likelihoodRatio, 0.2);
  });

  test('systemic warning overrides Bayesian review priority', () {
    final result = engine.fuse(
      analytes: analytes(),
      checklist: checklist(const ['fever']),
    );

    expect(result.utiEstimate.likelihoodBand, 'Lower');
    expect(result.riskBucket, 'High');
    expect(
      result.interpretations
          .singleWhere((item) => item.category == 'systemic_uti')
          .severity,
      'high',
    );
  });

  test('unavailable analytes are not treated as negative results', () {
    final result = engine.fuse(
      analytes: analytes(
        leukocytes: 'Unavailable',
        nitrite: 'Unavailable',
        blood: 'Unavailable',
      ),
      checklist: checklist(const ['frequency']),
    );

    expect(result.utiEstimate.factors, hasLength(1));
    expect(result.utiEstimate.factors.single.group, 'Urinary symptoms');
    expect(result.utiEstimate.posteriorProbability, closeTo(0.5238, 0.0001));
  });

  test(
    'no usable evidence does not expose the prior as a patient estimate',
    () {
      final result = engine.fuse(
        analytes: analytes(
          leukocytes: 'Unavailable',
          nitrite: 'Unavailable',
          blood: 'Unavailable',
        ),
        checklist: checklist(const []),
      );

      expect(result.utiEstimate.isCalculable, isFalse);
      expect(result.utiEstimate.likelihoodBand, 'Insufficient');
      expect(result.riskBucket, 'Low');
    },
  );
}
