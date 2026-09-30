import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/dipstick_results_data.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/models/scan_model.dart';

void main() {
  const engine = RenalFollowupEngine();

  ClinicalChecklistResult checklist(Iterable<String> selected) {
    final selectedSet = selected.toSet();
    return ClinicalChecklistResult(
      selectedSymptoms: {
        for (final item in clinicalSymptoms)
          item.id: selectedSet.contains(item.id),
      },
    );
  }

  DipstickResultRow row(String code, String name, String result) {
    return DipstickResultRow(
      code: code,
      name: name,
      result: result,
      referenceRange: 'Test reference',
      status: result.toLowerCase() == 'neg'
          ? DipstickResultStatus.negative
          : DipstickResultStatus.moderate,
    );
  }

  ScanResult scan({
    String protein = 'Neg',
    String blood = 'Neg',
    bool valid = true,
  }) {
    return ScanResult(
      id: 'test_scan',
      date: DateTime(2026, 9, 19),
      imagePath: 'test.jpg',
      status: valid ? 'normal' : 'invalid',
      confidence: valid ? 0.9 : 0,
      riskBucket: 'Unavailable',
      modelVersion: 'test_model',
      rows: [
        row('LEU', 'Leukocytes', 'Neg'),
        row('NIT', 'Nitrite', 'Neg'),
        row('URO', 'Urobilinogen', 'Normal'),
        row('PRO', 'Protein', protein),
        row('pH', 'pH', '6.0'),
        row('BLD', 'Blood', blood),
        row('SG', 'Specific Gravity', '1.015'),
        row('KET', 'Ketone', 'Neg'),
        row('BIL', 'Bilirubin', 'Neg'),
        row('GLU', 'Glucose', 'Neg'),
      ],
      padsDetected: valid ? 10 : 0,
      padsUnavailable: valid ? 0 : 10,
    );
  }

  RenalFollowupResult evaluate({
    String protein = 'Neg',
    String blood = 'Neg',
    bool valid = true,
    Iterable<String> selected = const [],
  }) {
    return engine.evaluate(
      scanResult: scan(protein: protein, blood: blood, valid: valid),
      checklist: checklist(selected),
      evaluatedAt: DateTime(2026, 9, 19),
    );
  }

  void expectRule(RenalFollowupResult result, String id) {
    expect(
      result.triggeredRules.map((item) => item.id),
      contains(id),
      reason: 'Expected $id in ${result.triggeredRules.map((item) => item.id)}',
    );
  }

  group('technical validity rules', () {
    test('TECH-01 invalid scan', () {
      final result = evaluate(valid: false);
      expectRule(result, 'TECH-01');
      expect(result.finalAction, RenalAction.retake);
    });

    test('TECH-02 strip quality, profile, and timing issue', () {
      for (final input in [
        'strip_expired',
        'strip_damaged',
        'read_outside_60_seconds',
        'unsupported_strip',
      ]) {
        expectRule(evaluate(selected: [input]), 'TECH-02');
      }
    });

    test('unknown protein category is unreliable', () {
      final result = evaluate(protein: 'Unknown');
      expectRule(result, 'TECH-01');
      expect(result.proteinReliable, isFalse);
    });
  });

  group('safety override rules', () {
    test('SAFE-01 visible blood with clot or obstruction', () {
      expectRule(evaluate(selected: ['hematuria', 'blood_clots']), 'SAFE-01');
      expectRule(
        evaluate(selected: ['hematuria', 'unable_to_urinate']),
        'SAFE-01',
      );
    });

    test('SAFE-02 reduced urine output', () {
      expectRule(evaluate(selected: ['reduced_urine_output']), 'SAFE-02');
    });

    test('SAFE-03 edema with shortness of breath', () {
      expectRule(
        evaluate(selected: ['edema', 'shortness_of_breath']),
        'SAFE-03',
      );
    });

    test('SAFE-04 fever with flank pain', () {
      expectRule(evaluate(selected: ['fever', 'flank']), 'SAFE-04');
    });

    test('SAFE-05 fever or flank pain with nausea', () {
      expectRule(evaluate(selected: ['fever', 'nausea']), 'SAFE-05');
      expectRule(evaluate(selected: ['flank', 'nausea']), 'SAFE-05');
    });

    test('SAFE-06 vomiting prevents hydration or medication', () {
      expectRule(
        evaluate(selected: ['nausea', 'cannot_hydrate_or_medicate']),
        'SAFE-06',
      );
    });

    test('SAFE-07 severe pain with visible or dipstick blood', () {
      expectRule(
        evaluate(selected: ['severe_flank_abdominal_pain', 'hematuria']),
        'SAFE-07',
      );
      expectRule(
        evaluate(blood: 'Small 25', selected: ['severe_flank_abdominal_pain']),
        'SAFE-07',
      );
    });

    test('SAFE-08 serious general symptom with urinary finding', () {
      expectRule(
        evaluate(selected: ['confusion_fainting_weakness', 'dysuria']),
        'SAFE-08',
      );
    });
  });

  group('interference rules', () {
    test('INT-01 bleeding or contamination with positive blood', () {
      expectRule(
        evaluate(
          blood: 'Hemolyzed 10',
          selected: ['menstruation_or_vaginal_bleeding'],
        ),
        'INT-01',
      );
      expectRule(
        evaluate(blood: 'Small 25', selected: ['possible_contamination']),
        'INT-01',
      );
    });

    test('INT-02 temporary conditions with detected protein', () {
      for (final input in [
        'strenuous_exercise',
        'fever',
        'dehydration',
        'acute_illness',
      ]) {
        expectRule(evaluate(protein: 'Trace', selected: [input]), 'INT-02');
      }
    });

    test('INT-03 explicit possible or managed UTI with protein', () {
      expectRule(
        evaluate(protein: 'Trace', selected: ['managed_or_possible_uti']),
        'INT-03',
      );
    });
  });

  group('protein rules', () {
    test('PRO-01 negative protein and blood', () {
      expectRule(evaluate(), 'PRO-01');
    });

    test('PRO-02 trace protein only', () {
      final result = evaluate(protein: 'Trace');
      expectRule(result, 'PRO-02');
      expect(result.finalAction, RenalAction.repeatConfirm);
    });

    test('PRO-03 every frozen positive protein category', () {
      for (final value in ['0.3', '1.0', '3.0', '>=20.0']) {
        expectRule(evaluate(protein: value), 'PRO-03');
      }
    });

    test('PRO-04 explicitly confirmed repeat protein', () {
      expectRule(evaluate(selected: ['repeat_protein_present']), 'PRO-04');
    });

    test('PRO-05 prior protein finding resolved on repeat', () {
      expectRule(evaluate(selected: ['repeat_abnormal_resolved']), 'PRO-05');
    });
  });

  group('blood rules', () {
    test('BLD-01 every frozen positive blood category', () {
      for (final value in [
        'Non-hemolyzed 10',
        'Hemolyzed 10',
        'Small 25',
        'Moderate 80',
        'Large 200',
      ]) {
        expectRule(evaluate(blood: value), 'BLD-01');
      }
    });

    test('BLD-02 visible blood without safety combination', () {
      expectRule(evaluate(selected: ['hematuria']), 'BLD-02');
    });

    test('BLD-03 repeat persistence or microscopy confirmation', () {
      expectRule(evaluate(selected: ['repeat_blood_present']), 'BLD-03');
      expectRule(evaluate(selected: ['blood_microscopy_confirmed']), 'BLD-03');
    });
  });

  group('combined and edema rules', () {
    test('COMB-01 positive protein with dipstick blood', () {
      expectRule(
        evaluate(protein: '0.3', blood: 'Non-hemolyzed 10'),
        'COMB-01',
      );
    });

    test('COMB-02 positive protein with edema', () {
      expectRule(evaluate(protein: '1.0', selected: ['edema']), 'COMB-02');
    });

    test('COMB-03 persistent or unexplained edema', () {
      expectRule(evaluate(selected: ['persistent_edema']), 'COMB-03');
    });

    test('trace protein does not activate positive-protein combinations', () {
      final result = evaluate(
        protein: 'Trace',
        blood: 'Small 25',
        selected: ['edema'],
      );
      expect(
        result.triggeredRules.map((item) => item.id),
        isNot(contains('COMB-01')),
      );
      expect(
        result.triggeredRules.map((item) => item.id),
        isNot(contains('COMB-02')),
      );
    });
  });

  group('priority conflicts and audit behavior', () {
    test('serious symptoms override invalid scan', () {
      final result = evaluate(valid: false, selected: ['fever', 'flank']);
      expectRule(result, 'TECH-01');
      expectRule(result, 'SAFE-04');
      expect(result.finalAction, RenalAction.promptConsult);
    });

    test('RETAKE overrides CONSULT when no safety trigger exists', () {
      final result = evaluate(protein: '1.0', selected: ['strip_expired']);
      expectRule(result, 'TECH-02');
      expectRule(result, 'PRO-03');
      expect(result.finalAction, RenalAction.retake);
    });

    test('CONSULT overrides REPEAT_CONFIRM', () {
      final result = evaluate(
        protein: '1.0',
        blood: 'Small 25',
        selected: ['possible_contamination'],
      );
      expectRule(result, 'INT-01');
      expectRule(result, 'COMB-01');
      expect(result.finalAction, RenalAction.consult);
    });

    test('REPEAT_CONFIRM is selected for a trace-only finding', () {
      final result = evaluate(protein: 'Trace');
      expectRule(result, 'PRO-02');
      expect(result.finalAction, RenalAction.repeatConfirm);
    });

    test('all triggered IDs and final action survive JSON round-trip', () {
      final original = evaluate(
        protein: '1.0',
        blood: 'Small 25',
        selected: ['edema', 'persistent_edema'],
      );
      final restored = RenalFollowupResult.fromJson(original.toJson());
      expect(restored.version, RenalFollowupResult.ruleSetVersion);
      expect(restored.messageVersion, original.messageVersion);
      expect(restored.finalAction, original.finalAction);
      expect(
        restored.triggeredRules.map((item) => item.id),
        original.triggeredRules.map((item) => item.id),
      );
      expect(restored.stripProfile, Urs10TProfile.profileId);
    });
  });
}
