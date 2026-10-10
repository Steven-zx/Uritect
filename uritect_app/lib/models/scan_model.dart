import 'dipstick_results_data.dart';
import 'scan_provenance.dart';

class ScanResult {
  final String id;
  final DateTime date;
  final String imagePath;
  final String status; // 'normal', 'moderate', 'critical'
  final double confidence;
  final Map<String, double> analyteConfidences;
  final String riskBucket;
  final String modelVersion;
  final String? pipelineVersion;
  final List<DipstickResultRow> rows;
  final int? padsDetected;
  final int? padsUnavailable;
  final String? rejectionCode;
  final String? rejectionReason;
  final bool stripDirectionVerified;
  final bool modelDirectionReviewed;
  final bool supportCheckPassed;
  final Map<String, double> nearestTrainingDistances;
  final ScanProvenance? provenance;

  const ScanResult({
    required this.id,
    required this.date,
    required this.imagePath,
    required this.status,
    required this.confidence,
    this.analyteConfidences = const {},
    required this.riskBucket,
    required this.modelVersion,
    this.pipelineVersion,
    required this.rows,
    this.padsDetected,
    this.padsUnavailable,
    this.rejectionCode,
    this.rejectionReason,
    this.stripDirectionVerified = false,
    this.modelDirectionReviewed = false,
    this.supportCheckPassed = false,
    this.nearestTrainingDistances = const {},
    this.provenance,
  });

  static const double minimumInterpretationConfidence = 0.45;
  static const Map<String, String> expectedAnalytes = {
    'LEU': 'Leukocytes',
    'NIT': 'Nitrite',
    'URO': 'Urobilinogen',
    'PRO': 'Protein',
    'pH': 'pH',
    'BLD': 'Blood',
    'SG': 'Specific Gravity',
    'KET': 'Ketone',
    'BIL': 'Bilirubin',
    'GLU': 'Glucose',
  };

  bool get hasQuarantinedOrientationModel =>
      modelVersion ==
      'production_semiquant_knn_markerless_roi_topfix_v3_20260908';

  bool get hasCompleteSafetyMetadata =>
      !hasQuarantinedOrientationModel &&
      stripDirectionVerified &&
      modelDirectionReviewed &&
      padsDetected == 10 &&
      padsUnavailable == 0 &&
      rows.length == 10 &&
      rows.map((r) => r.code).toSet().length == 10 &&
      rows.every((r) => expectedAnalytes[r.code] == r.name) &&
      analyteConfidences.length == 10 &&
      analyteConfidences.keys.toSet().containsAll(expectedAnalytes.values) &&
      analyteConfidences.values.every((v) => v.isFinite && v >= 0 && v <= 1) &&
      supportCheckPassed &&
      nearestTrainingDistances.length == 10 &&
      nearestTrainingDistances.keys.toSet().containsAll(
        expectedAnalytes.values,
      ) &&
      nearestTrainingDistances.values.every((v) => v.isFinite && v >= 0);
  bool get isLegacyUnverified => rows.isNotEmpty && !hasCompleteSafetyMetadata;
  bool get isUsableForCurrentInterpretation =>
      isReliableForInterpretation &&
      provenance?.canSupportCurrentContext == true;

  // The experimental model's existing vote gate remains 0.55. A weak pH
  // reading must not invalidate independently adequate UTI-input pads.
  double get requiredAnalyteConfidence =>
      modelVersion.startsWith('direction_verified_experimental_')
      ? 0.55
      : minimumInterpretationConfidence;

  bool hasUsableAnalytesForCurrentInterpretation(Set<String> codes) =>
      codes.isNotEmpty &&
      codes.every(expectedAnalytes.containsKey) &&
      const {
        'complete',
        'normal',
        'moderate',
        'critical',
        'review_required',
      }.contains(status) &&
      hasCompleteSafetyMetadata &&
      confidence.isFinite &&
      confidence >=
          (status == 'review_required' &&
                  modelVersion.startsWith('direction_verified_experimental_')
              ? 0
              : minimumInterpretationConfidence) &&
      confidence <= 1 &&
      provenance?.canSupportCurrentContext == true &&
      codes.every(
        (code) =>
            analyteConfidences[expectedAnalytes[code]]! >=
            requiredAnalyteConfidence,
      );

  bool get isReliableForInterpretation =>
      const {'complete', 'normal', 'moderate', 'critical'}.contains(status) &&
      hasCompleteSafetyMetadata &&
      confidence.isFinite &&
      confidence >= minimumInterpretationConfidence &&
      confidence <= 1 &&
      rows.every((row) {
        final value = analyteConfidences[row.name];
        return value != null &&
            value.isFinite &&
            value >= requiredAnalyteConfidence;
      });

  factory ScanResult.empty({
    required String imagePath,
    String id = 'scan_pending',
  }) {
    return ScanResult(
      id: id,
      date: DateTime.now(),
      imagePath: imagePath,
      status: 'moderate',
      confidence: 0.0,
      riskBucket: 'Moderate',
      modelVersion: 'trained_v4_hsv',
      rows: const <DipstickResultRow>[],
    );
  }

  ScanResult copyWith({
    String? id,
    DateTime? date,
    String? imagePath,
    String? status,
    double? confidence,
    Map<String, double>? analyteConfidences,
    String? riskBucket,
    String? modelVersion,
    String? pipelineVersion,
    List<DipstickResultRow>? rows,
    int? padsDetected,
    int? padsUnavailable,
    String? rejectionCode,
    String? rejectionReason,
    bool? stripDirectionVerified,
    bool? modelDirectionReviewed,
    bool? supportCheckPassed,
    Map<String, double>? nearestTrainingDistances,
    ScanProvenance? provenance,
  }) {
    return ScanResult(
      id: id ?? this.id,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      analyteConfidences: analyteConfidences ?? this.analyteConfidences,
      riskBucket: riskBucket ?? this.riskBucket,
      modelVersion: modelVersion ?? this.modelVersion,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
      rows: rows ?? this.rows,
      padsDetected: padsDetected ?? this.padsDetected,
      padsUnavailable: padsUnavailable ?? this.padsUnavailable,
      rejectionCode: rejectionCode ?? this.rejectionCode,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      stripDirectionVerified:
          stripDirectionVerified ?? this.stripDirectionVerified,
      modelDirectionReviewed:
          modelDirectionReviewed ?? this.modelDirectionReviewed,
      supportCheckPassed: supportCheckPassed ?? this.supportCheckPassed,
      nearestTrainingDistances:
          nearestTrainingDistances ?? this.nearestTrainingDistances,
      provenance: provenance ?? this.provenance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'status': status,
      'confidence': confidence,
      'analyteConfidences': analyteConfidences,
      'riskBucket': riskBucket,
      'modelVersion': modelVersion,
      'pipeline_version': pipelineVersion,
      'rows': rows.map((row) => row.toJson()).toList(),
      'padsDetected': padsDetected,
      'padsUnavailable': padsUnavailable,
      'rejectionCode': rejectionCode,
      'rejectionReason': rejectionReason,
      'stripDirectionVerified': stripDirectionVerified,
      'modelDirectionReviewed': modelDirectionReviewed,
      'supportCheckPassed': supportCheckPassed,
      'nearestTrainingDistances': nearestTrainingDistances,
      'provenance': provenance?.toJson(),
    };
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? const [];
    int? count(Object? value) =>
        value is num && value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : null;
    return ScanResult(
      id: json['id'] as String? ?? 'scan_missing',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      imagePath: json['imagePath'] as String? ?? '',
      status: json['status'] as String? ?? 'moderate',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      analyteConfidences:
          (json['analyteConfidences'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ),
      riskBucket: json['riskBucket'] as String? ?? 'Moderate',
      modelVersion: json['modelVersion'] as String? ?? 'unknown',
      pipelineVersion: json['pipeline_version'] as String?,
      rows: rawRows
          .map((row) => DipstickResultRow.fromJson(row as Map<String, dynamic>))
          .toList(),
      padsDetected: count(json['padsDetected']),
      padsUnavailable: count(json['padsUnavailable']),
      rejectionCode: json['rejectionCode'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      stripDirectionVerified: json['stripDirectionVerified'] == true,
      modelDirectionReviewed: json['modelDirectionReviewed'] == true,
      supportCheckPassed: json['supportCheckPassed'] == true,
      nearestTrainingDistances:
          (json['nearestTrainingDistances'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
      provenance: json['provenance'] is Map<String, dynamic>
          ? ScanProvenance.fromJson(json['provenance'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AnalyteResult {
  final String code;
  final String name;
  final String level;
  final String status; // 'normal', 'moderate', 'high'
  final String referenceRange;

  const AnalyteResult({
    required this.code,
    required this.name,
    required this.level,
    required this.status,
    required this.referenceRange,
  });

  DipstickResultRow toRow() {
    return DipstickResultRow(
      code: code,
      name: name,
      result: level,
      referenceRange: referenceRange,
      status: status == 'high' || status == 'moderate'
          ? DipstickResultStatus.moderate
          : DipstickResultStatus.negative,
    );
  }
}
