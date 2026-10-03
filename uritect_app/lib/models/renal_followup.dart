import 'clinical_symptoms.dart';
import 'dipstick_results_data.dart';
import 'scan_model.dart';

enum RenalAction { observe, repeatConfirm, consult, retake, promptConsult }

extension RenalActionDetails on RenalAction {
  String get code => switch (this) {
    RenalAction.observe => 'OBSERVE',
    RenalAction.repeatConfirm => 'REPEAT_CONFIRM',
    RenalAction.consult => 'CONSULT',
    RenalAction.retake => 'RETAKE',
    RenalAction.promptConsult => 'PROMPT_CONSULT',
  };

  int get priority => switch (this) {
    RenalAction.observe => 1,
    RenalAction.repeatConfirm => 2,
    RenalAction.consult => 3,
    RenalAction.retake => 4,
    RenalAction.promptConsult => 5,
  };

  String get heading => switch (this) {
    RenalAction.observe => 'Observe for symptoms',
    RenalAction.repeatConfirm => 'Repeat or confirm the test',
    RenalAction.consult => 'Consultation suggested',
    RenalAction.retake => 'Unable to interpret - retake the scan',
    RenalAction.promptConsult => 'Seek prompt medical consultation',
  };

  String get message => switch (this) {
    RenalAction.observe =>
      'No renal-related follow-up trigger was identified from the available reliable results and reported symptoms. This does not rule out a kidney or urinary tract condition. Consult a healthcare professional if symptoms appear, continue, or worsen.',
    RenalAction.repeatConfirm =>
      'A finding was detected that may be affected by sample collection or a temporary condition. A properly collected repeat urine test or professional consultation for confirmatory testing may be appropriate.',
    RenalAction.consult =>
      'A urine-strip finding or related symptom was reported. These findings can have several causes and cannot diagnose kidney disease. Consultation with a healthcare professional and confirmatory laboratory testing are suggested.',
    RenalAction.retake =>
      'The relevant urine-strip result could not be interpreted reliably. Repeat the test using the supported strip, collection method, timing, and scanning procedure. Seek professional care based on symptoms even if scanning is unsuccessful.',
    RenalAction.promptConsult =>
      'A warning symptom or finding was reported. Please seek prompt medical consultation. If you feel severely unwell or symptoms rapidly worsen, seek emergency medical assistance. This result is not a diagnosis.',
  };
}

class Urs10TProfile {
  static const String profileId = 'urs10t_protein_blood_60s_v1';
  static const String product = 'URS-10T reagent strip';
  static const String manufacturer = 'Pending physical bottle/IFU confirmation';
  static const String ifuRevision = 'Pending physical bottle/IFU confirmation';
  static const int proteinReactionSeconds = 60;
  static const int bloodReactionSeconds = 60;

  static const Set<String> proteinNegative = {'neg', 'negative'};
  static const Set<String> proteinTrace = {'trace'};
  static const Set<String> proteinPositive = {
    '0.3',
    '1.0',
    '3.0',
    '>=20.0',
    '>20.0',
  };
  static const Set<String> bloodNegative = {'neg', 'negative'};
  static const Set<String> bloodPositive = {
    'non-hemolyzed 10',
    'non hemolyzed 10',
    'hemolyzed 10',
    'small 25',
    'moderate 80',
    'large 200',
    'trace',
  };
}

class TriggeredRenalRule {
  final String id;
  final RenalAction action;
  final String explanation;

  const TriggeredRenalRule({
    required this.id,
    required this.action,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.code,
    'explanation': explanation,
  };

  factory TriggeredRenalRule.fromJson(Map<String, dynamic> json) {
    final actionCode = json['action'] as String? ?? 'OBSERVE';
    return TriggeredRenalRule(
      id: json['id'] as String? ?? 'UNKNOWN',
      action: RenalAction.values.firstWhere(
        (item) => item.code == actionCode,
        orElse: () => RenalAction.observe,
      ),
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class RenalFollowupResult {
  static const String ruleSetVersion = 'renal_followup_rules_v1.1_20260919';
  static const String currentMessageVersion = 'renal_messages_v1.1_20260919';

  final String version;
  final String messageVersion;
  final String stripProfile;
  final bool scanValid;
  final String proteinCategory;
  final String bloodCategory;
  final bool proteinReliable;
  final bool bloodReliable;
  final List<TriggeredRenalRule> triggeredRules;
  final RenalAction finalAction;
  final Map<String, bool> inputsUsed;
  final DateTime evaluatedAt;

  const RenalFollowupResult({
    required this.version,
    required this.messageVersion,
    required this.stripProfile,
    required this.scanValid,
    required this.proteinCategory,
    required this.bloodCategory,
    required this.proteinReliable,
    required this.bloodReliable,
    required this.triggeredRules,
    required this.finalAction,
    required this.inputsUsed,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'stripProfile': stripProfile,
    'scanValid': scanValid,
    'proteinCategory': proteinCategory,
    'bloodCategory': bloodCategory,
    'proteinReliable': proteinReliable,
    'bloodReliable': bloodReliable,
    'triggeredRules': triggeredRules.map((item) => item.toJson()).toList(),
    'finalAction': finalAction.code,
    'messageVersion': messageVersion,
    'inputsUsed': inputsUsed,
    'evaluatedAt': evaluatedAt.toIso8601String(),
  };

  factory RenalFollowupResult.fromJson(Map<String, dynamic> json) {
    final actionCode = json['finalAction'] as String? ?? 'OBSERVE';
    final rawRules = json['triggeredRules'] as List<dynamic>? ?? const [];
    final rawInputs = json['inputsUsed'] as Map<String, dynamic>? ?? const {};
    return RenalFollowupResult(
      version: json['version'] as String? ?? ruleSetVersion,
      messageVersion:
          json['messageVersion'] as String? ?? currentMessageVersion,
      stripProfile: json['stripProfile'] as String? ?? Urs10TProfile.profileId,
      scanValid: json['scanValid'] == true,
      proteinCategory: json['proteinCategory'] as String? ?? 'Unavailable',
      bloodCategory: json['bloodCategory'] as String? ?? 'Unavailable',
      proteinReliable: json['proteinReliable'] == true,
      bloodReliable: json['bloodReliable'] == true,
      triggeredRules: rawRules
          .whereType<Map<String, dynamic>>()
          .map(TriggeredRenalRule.fromJson)
          .toList(),
      finalAction: RenalAction.values.firstWhere(
        (item) => item.code == actionCode,
        orElse: () => RenalAction.observe,
      ),
      inputsUsed: {
        for (final entry in rawInputs.entries) entry.key: entry.value == true,
      },
      evaluatedAt:
          DateTime.tryParse(json['evaluatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class RenalFollowupEngine {
  const RenalFollowupEngine();

  RenalFollowupResult evaluate({
    required ScanResult scanResult,
    required ClinicalChecklistResult checklist,
    DateTime? evaluatedAt,
  }) {
    final flags = checklist.selectedSymptoms;
    bool flag(String id) => flags[id] == true;

    final protein = _findResult(scanResult.rows, 'PRO', 'Protein');
    final blood = _findResult(scanResult.rows, 'BLD', 'Blood');
    final scanValid = scanResult.isReliableForInterpretation;
    final proteinValue = _normalize(protein?.result);
    final bloodValue = _normalize(blood?.result);
    final testQualityFailed =
        flag('strip_expired') ||
        flag('strip_damaged') ||
        flag('read_outside_60_seconds') ||
        flag('unsupported_strip');
    final proteinReliable =
        scanValid && !testQualityFailed && _isKnownProtein(proteinValue);
    final bloodReliable =
        scanValid && !testQualityFailed && _isKnownBlood(bloodValue);
    final proteinTrace =
        proteinReliable && Urs10TProfile.proteinTrace.contains(proteinValue);
    final proteinPositive =
        proteinReliable && Urs10TProfile.proteinPositive.contains(proteinValue);
    final proteinDetected = proteinTrace || proteinPositive;
    final proteinNegative =
        proteinReliable && Urs10TProfile.proteinNegative.contains(proteinValue);
    final bloodPositive =
        bloodReliable && Urs10TProfile.bloodPositive.contains(bloodValue);
    final bloodNegative =
        bloodReliable && Urs10TProfile.bloodNegative.contains(bloodValue);
    final visibleBlood = flag('hematuria');
    final edema = flag('edema');
    final systemicUrinaryFinding =
        visibleBlood ||
        proteinDetected ||
        bloodPositive ||
        flag('dysuria') ||
        flag('frequency') ||
        flag('urgency') ||
        flag('unable_to_urinate') ||
        flag('reduced_urine_output');

    final rules = <TriggeredRenalRule>[];
    void trigger(String id, RenalAction action, String explanation) {
      rules.add(
        TriggeredRenalRule(id: id, action: action, explanation: explanation),
      );
    }

    if (!scanValid || !proteinReliable || !bloodReliable) {
      trigger(
        'TECH-01',
        RenalAction.retake,
        'The scan or the protein/blood result is not reliable enough to interpret.',
      );
    }
    if (flag('strip_expired') ||
        flag('strip_damaged') ||
        flag('read_outside_60_seconds') ||
        flag('unsupported_strip')) {
      trigger(
        'TECH-02',
        RenalAction.retake,
        'A strip quality, supported-product, or 60-second timing requirement was not met.',
      );
    }

    if (visibleBlood && (flag('blood_clots') || flag('unable_to_urinate'))) {
      trigger(
        'SAFE-01',
        RenalAction.promptConsult,
        'Visible blood was reported with clots or inability to urinate.',
      );
    }
    if (flag('reduced_urine_output')) {
      trigger(
        'SAFE-02',
        RenalAction.promptConsult,
        'Markedly reduced or absent urine output was reported.',
      );
    }
    if (edema && flag('shortness_of_breath')) {
      trigger(
        'SAFE-03',
        RenalAction.promptConsult,
        'Swelling was reported with shortness of breath.',
      );
    }
    if (flag('fever') && flag('flank')) {
      trigger(
        'SAFE-04',
        RenalAction.promptConsult,
        'Fever or chills was reported with flank or back pain.',
      );
    }
    if ((flag('fever') || flag('flank')) && flag('nausea')) {
      trigger(
        'SAFE-05',
        RenalAction.promptConsult,
        'Fever or flank/back pain was reported with nausea or vomiting.',
      );
    }
    if (flag('nausea') && flag('cannot_hydrate_or_medicate')) {
      trigger(
        'SAFE-06',
        RenalAction.promptConsult,
        'Vomiting was reported to prevent fluids or oral medication.',
      );
    }
    if (flag('severe_flank_abdominal_pain') &&
        (visibleBlood || bloodPositive)) {
      trigger(
        'SAFE-07',
        RenalAction.promptConsult,
        'Severe flank or abdominal pain was reported with visible or dipstick-detected blood.',
      );
    }
    if (flag('confusion_fainting_weakness') && systemicUrinaryFinding) {
      trigger(
        'SAFE-08',
        RenalAction.promptConsult,
        'A serious general symptom was reported with a urinary finding.',
      );
    }

    final hasSafetyRule = rules.any(
      (item) => item.action == RenalAction.promptConsult,
    );
    if (bloodPositive &&
        (flag('menstruation_or_vaginal_bleeding') ||
            flag('possible_contamination'))) {
      trigger(
        'INT-01',
        RenalAction.repeatConfirm,
        'Possible bleeding or specimen contamination may affect the blood pad.',
      );
    }
    if (proteinDetected &&
        (flag('strenuous_exercise') ||
            flag('fever') ||
            flag('dehydration') ||
            flag('acute_illness'))) {
      trigger(
        'INT-02',
        RenalAction.repeatConfirm,
        'A temporary condition may affect urine protein.',
      );
    }
    if (proteinDetected && flag('managed_or_possible_uti')) {
      trigger(
        'INT-03',
        RenalAction.consult,
        'Protein was detected with an explicitly reported possible or clinically managed UTI.',
      );
    }

    if (proteinNegative &&
        bloodNegative &&
        !edema &&
        !visibleBlood &&
        !hasSafetyRule) {
      trigger(
        'PRO-01',
        RenalAction.observe,
        'Protein and blood were negative and no renal follow-up symptom was reported.',
      );
    }
    if (proteinTrace && bloodNegative && !edema && !hasSafetyRule) {
      trigger(
        'PRO-02',
        RenalAction.repeatConfirm,
        'Trace protein was detected without blood or edema.',
      );
    }
    if (proteinPositive) {
      trigger(
        'PRO-03',
        RenalAction.consult,
        'Protein was 0.3 g/L or higher and should be professionally interpreted and quantitatively confirmed.',
      );
    }
    if (flag('repeat_protein_present')) {
      trigger(
        'PRO-04',
        RenalAction.consult,
        'Protein was reported to remain present on a properly collected repeat test.',
      );
    }
    if (proteinNegative &&
        flag('repeat_abnormal_resolved') &&
        !edema &&
        !visibleBlood &&
        !hasSafetyRule) {
      trigger(
        'PRO-05',
        RenalAction.observe,
        'A previous protein finding was reported to have become negative on repeat.',
      );
    }

    if (bloodPositive && !visibleBlood && !hasSafetyRule) {
      trigger(
        'BLD-01',
        RenalAction.repeatConfirm,
        'Dipstick blood was detected without visible blood or a safety trigger.',
      );
    }
    if (visibleBlood && !hasSafetyRule) {
      trigger(
        'BLD-02',
        RenalAction.consult,
        'Visible blood was reported without a prompt-consultation combination.',
      );
    }
    if (flag('repeat_blood_present') || flag('blood_microscopy_confirmed')) {
      trigger(
        'BLD-03',
        RenalAction.consult,
        'Blood was reported as persistent on repeat or confirmed by microscopy.',
      );
    }

    if (proteinPositive && bloodPositive) {
      trigger(
        'COMB-01',
        RenalAction.consult,
        'Protein 0.3 g/L or higher and dipstick blood were both detected.',
      );
    }
    if (proteinPositive && edema) {
      trigger(
        'COMB-02',
        RenalAction.consult,
        'Protein 0.3 g/L or higher was detected with edema or unusual swelling.',
      );
    }
    if (flag('persistent_edema')) {
      trigger(
        'COMB-03',
        RenalAction.consult,
        'Persistent or unexplained edema was reported.',
      );
    }

    if (rules.isEmpty) {
      trigger(
        'DEFAULT-OBSERVE',
        RenalAction.observe,
        'No follow-up rule was triggered by the available reliable inputs.',
      );
    }
    var finalAction = RenalAction.observe;
    for (final rule in rules) {
      if (rule.action.priority > finalAction.priority) {
        finalAction = rule.action;
      }
    }

    return RenalFollowupResult(
      version: RenalFollowupResult.ruleSetVersion,
      messageVersion: RenalFollowupResult.currentMessageVersion,
      stripProfile: Urs10TProfile.profileId,
      scanValid: scanValid,
      proteinCategory: protein?.result ?? 'Unavailable',
      bloodCategory: blood?.result ?? 'Unavailable',
      proteinReliable: proteinReliable,
      bloodReliable: bloodReliable,
      triggeredRules: List.unmodifiable(rules),
      finalAction: finalAction,
      inputsUsed: Map.unmodifiable({
        for (final item in clinicalSymptoms) item.id: flag(item.id),
      }),
      evaluatedAt: evaluatedAt ?? DateTime.now(),
    );
  }

  static DipstickResultRow? _findResult(
    List<DipstickResultRow> rows,
    String code,
    String name,
  ) {
    for (final row in rows) {
      if (row.code.toUpperCase() == code ||
          row.name.toLowerCase() == name.toLowerCase()) {
        return row;
      }
    }
    return null;
  }

  static String _normalize(String? value) => (value ?? '').trim().toLowerCase();
  static bool _isKnownProtein(String value) =>
      Urs10TProfile.proteinNegative.contains(value) ||
      Urs10TProfile.proteinTrace.contains(value) ||
      Urs10TProfile.proteinPositive.contains(value);
  static bool _isKnownBlood(String value) =>
      Urs10TProfile.bloodNegative.contains(value) ||
      Urs10TProfile.bloodPositive.contains(value);
}
