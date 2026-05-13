import 'dipstick_results_data.dart';

class ScanResult {
  final String id;
  final DateTime date;
  final String imagePath;
  final String status; // 'normal', 'moderate', 'critical'
  final double confidence;
  final double posteriorProbability;
  final String riskBucket;
  final String modelVersion;
  final List<DipstickResultRow> rows;
  final Map<String, double> screeningProbabilities;
  final int? padsDetected;
  final int? padsUnavailable;

  const ScanResult({
    required this.id,
    required this.date,
    required this.imagePath,
    required this.status,
    required this.confidence,
    required this.posteriorProbability,
    required this.riskBucket,
    required this.modelVersion,
    required this.rows,
    required this.screeningProbabilities,
    this.padsDetected,
    this.padsUnavailable,
  });

  factory ScanResult.empty({required String imagePath, String id = 'scan_pending'}) {
    return ScanResult(
      id: id,
      date: DateTime.now(),
      imagePath: imagePath,
      status: 'moderate',
      confidence: 0.0,
      posteriorProbability: 0.0,
      riskBucket: 'Moderate',
      modelVersion: 'trained_v4_hsv',
      rows: const <DipstickResultRow>[],
      screeningProbabilities: const <String, double>{},
    );
  }

  ScanResult copyWith({
    String? id,
    DateTime? date,
    String? imagePath,
    String? status,
    double? confidence,
    double? posteriorProbability,
    String? riskBucket,
    String? modelVersion,
    List<DipstickResultRow>? rows,
    Map<String, double>? screeningProbabilities,
    int? padsDetected,
    int? padsUnavailable,
  }) {
    return ScanResult(
      id: id ?? this.id,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      posteriorProbability: posteriorProbability ?? this.posteriorProbability,
      riskBucket: riskBucket ?? this.riskBucket,
      modelVersion: modelVersion ?? this.modelVersion,
      rows: rows ?? this.rows,
      screeningProbabilities: screeningProbabilities ?? this.screeningProbabilities,
      padsDetected: padsDetected ?? this.padsDetected,
      padsUnavailable: padsUnavailable ?? this.padsUnavailable,
    );
  }
}

class AnalyteResult {
  final String code;
  final String name;
  final String level;
  final String status; // 'normal', 'moderate', 'high'
  final String referenceRange;
  final double? abnormalProbability;

  const AnalyteResult({
    required this.code,
    required this.name,
    required this.level,
    required this.status,
    required this.referenceRange,
    this.abnormalProbability,
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
