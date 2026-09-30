import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/screening_fusion.dart';

void main() {
  const engine = ScreeningFusionEngine();

  ClinicalChecklistResult checklist(
    List<String> selected, {
    bool eligible = true,
  }) {
    final selections = <String>{
      ...selected,
      if (eligible) ...ScreeningFusionEngine.eligibilityConfirmations,
    };
    return ClinicalChecklistResult(
      selectedSymptoms: {
        for (final item in clinicalSymptoms)
          item.id: selections.contains(item.id),
      },
    );
  }

  List<ScreeningAnalyteResult> analytes({
    String leukocytes = 'Neg',
    String nitrite = 'Neg',
    String blood = 'Neg',
  }) => [
    ScreeningAnalyteResult(
      code: 'LEU',
      name: 'Leukocytes',
      displayValue: leukocytes,
    ),
    ScreeningAnalyteResult(code: 'NIT', name: 'Nitrite', displayValue: nitrite),
    ScreeningAnalyteResult(code: 'BLD', name: 'Blood', displayValue: blood),
  ];

  test(
    'all-negative pattern is calculated only for eligible symptomatic user',
    () {
      final result = engine.fuse(
        analytes: analytes(),
        checklist: checklist(const ['dysuria']),
      );
      expect(result.utiEstimate.calculationStatus, 'calculated');
      expect(result.utiEstimate.factors.map((item) => item.likelihoodRatio), [
        0.22,
        1.3,
      ]);
      expect(result.utiEstimate.posteriorProbability, closeTo(0.2224, 0.0001));
    },
  );

  test('correlated positive dipsticks use one grouped LR', () {
    final result = engine.fuse(
      analytes: analytes(leukocytes: 'Moderate 125', nitrite: 'Positive'),
      checklist: checklist(const ['dysuria', 'urgency']),
    );
    expect(result.utiEstimate.factors, hasLength(2));
    expect(result.utiEstimate.factors[0].likelihoodRatio, 7.2);
    expect(result.utiEstimate.factors[1].likelihoodRatio, 1.5);
    expect(result.utiEstimate.posteriorProbability, closeTo(0.9153, 0.0001));
    expect(result.clinicalAction, 'Consultation suggested');
  });

  test('vaginal finding routes to consultation without numerical LR', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const ['dysuria', 'vaginal_irritation']),
    );
    expect(result.utiEstimate.isCalculable, isFalse);
    expect(result.utiEstimate.calculationStatus, 'not_designed');
    expect(result.utiEstimate.factors, isEmpty);
    expect(
      result.interpretations
          .singleWhere((item) => item.category == 'alternate_cause')
          .message,
      contains('Consultation'),
    );
  });

  test('visible hematuria is context and is never a numerical factor', () {
    final result = engine.fuse(
      analytes: analytes(blood: 'Hemolyzed 10'),
      checklist: checklist(const ['hematuria']),
    );
    expect(result.utiEstimate.isCalculable, isTrue);
    expect(result.utiEstimate.factors, hasLength(1));
    expect(result.utiEstimate.factors.single.likelihoodRatio, 1.7);
    expect(
      result.utiEstimate.factors.any(
        (item) => item.finding.contains('Visible'),
      ),
      isFalse,
    );
  });

  test('study thresholds exclude trace leukocytes and nonhemolyzed blood', () {
    final result = engine.fuse(
      analytes: analytes(leukocytes: 'Trace 15', blood: 'Non-hemolyzed 10'),
      checklist: checklist(const ['suprapubic']),
    );
    expect(result.utiEstimate.isCalculable, isFalse);
    expect(result.utiEstimate.calculationStatus, 'insufficient');
  });

  test('study thresholds include plus leukocytes and hemolyzed blood', () {
    final leukocyteResult = engine.fuse(
      analytes: analytes(leukocytes: 'Small 70', blood: 'Unavailable'),
      checklist: checklist(const ['suprapubic']),
    );
    final bloodResult = engine.fuse(
      analytes: analytes(leukocytes: 'Unavailable', blood: 'Hemolyzed 10'),
      checklist: checklist(const ['suprapubic']),
    );
    expect(leukocyteResult.utiEstimate.factors.single.likelihoodRatio, 1.4);
    expect(bloodResult.utiEstimate.factors.single.likelihoodRatio, 1.7);
  });

  test('incomplete population confirmation blocks calculation', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const ['dysuria'], eligible: false),
    );
    expect(result.utiEstimate.calculationStatus, 'not_designed');
    expect(result.utiEstimate.statusReason, contains('eligibility'));
  });

  test('asymptomatic screening sample blocks calculation', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const []),
    );
    expect(result.utiEstimate.calculationStatus, 'not_designed');
    expect(
      result.utiEstimate.statusReason,
      contains('No acute urinary symptom'),
    );
  });

  test('nausea alone does not trigger prompt consultation', () {
    final result = engine.fuse(
      analytes: analytes(),
      checklist: checklist(const ['dysuria', 'nausea']),
    );
    final warning = result.interpretations.singleWhere(
      (item) => item.category == 'systemic_uti',
    );
    expect(warning.severity, 'caution');
    expect(warning.title, isNot(contains('Prompt')));
  });

  test('fever with flank pain triggers prompt consultation', () {
    final result = engine.fuse(
      analytes: analytes(),
      checklist: checklist(const ['dysuria', 'fever', 'flank']),
    );
    final warning = result.interpretations.singleWhere(
      (item) => item.category == 'systemic_uti',
    );
    expect(warning.severity, 'high');
    expect(warning.title, 'Prompt medical consultation suggested');
    expect(result.utiEstimate.isCalculable, isFalse);
  });

  test('unselected symptoms are unknown and do not apply negative LRs', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const ['suprapubic']),
    );
    expect(result.utiEstimate.factors, hasLength(1));
    expect(result.utiEstimate.factors.single.likelihoodRatio, 5.5);
  });

  test('patient interpretation contains no probability or likelihood band', () {
    final result = engine.fuse(
      analytes: analytes(nitrite: 'Positive'),
      checklist: checklist(const ['dysuria']),
    );
    final item = result.interpretations.singleWhere(
      (value) => value.category == 'uti_screening',
    );
    expect(
      item.title,
      isNot(
        anyOf(contains('Lower'), contains('Intermediate'), contains('Higher')),
      ),
    );
    expect(item.message, isNot(contains('%')));
    expect(
      result.clinicalAction,
      isNot(anyOf(equals('Low'), equals('Moderate'), equals('High'))),
    );
  });

  test('systemic warning uses action wording rather than a risk band', () {
    final result = engine.fuse(
      analytes: analytes(),
      checklist: checklist(const ['dysuria', 'fever', 'flank']),
    );
    expect(result.clinicalAction, 'Prompt medical consultation suggested');
  });

  test('Bayesian factors survive JSON serialization', () {
    const factor = BayesianEvidenceFactor(
      group: 'Dipstick',
      finding: 'Nitrite positive',
      likelihoodRatio: 5.5,
      source: 'Test source',
    );
    final restored = BayesianEvidenceFactor.fromJson(factor.toJson());
    expect(restored.group, factor.group);
    expect(restored.finding, factor.finding);
    expect(restored.likelihoodRatio, factor.likelihoodRatio);
    expect(restored.source, factor.source);
  });
}
