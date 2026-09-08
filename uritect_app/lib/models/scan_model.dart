import 'dipstick_results_data.dart';

class ScanResult {
  final String id;
  final DateTime date;
  final String imagePath;
  final String status; // 'normal', 'moderate', 'critical'
  final double confidence;
  final String riskBucket;
  final String modelVersion;
  final List<DipstickResultRow> rows;
  final int? padsDetected;
  final int? padsUnavailable;

  const ScanResult({
    required this.id,
    required this.date,
    required this.imagePath,
    required this.status,
    required this.confidence,
    required this.riskBucket,
    required this.modelVersion,
    required this.rows,
    this.padsDetected,
    this.padsUnavailable,
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
    String? riskBucket,
    String? modelVersion,
    List<DipstickResultRow>? rows,
    int? padsDetected,
    int? padsUnavailable,
  }) {
    return ScanResult(
      id: id ?? this.id,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      riskBucket: riskBucket ?? this.riskBucket,
      modelVersion: modelVersion ?? this.modelVersion,
      rows: rows ?? this.rows,
      padsDetected: padsDetected ?? this.padsDetected,
      padsUnavailable: padsUnavailable ?? this.padsUnavailable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'status': status,
      'confidence': confidence,
      'riskBucket': riskBucket,
      'modelVersion': modelVersion,
      'rows': rows.map((row) => row.toJson()).toList(),
      'padsDetected': padsDetected,
      'padsUnavailable': padsUnavailable,
    };
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? const [];
    return ScanResult(
      id: json['id'] as String? ?? 'scan_missing',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      imagePath: json['imagePath'] as String? ?? '',
      status: json['status'] as String? ?? 'moderate',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      riskBucket: json['riskBucket'] as String? ?? 'Moderate',
      modelVersion: json['modelVersion'] as String? ?? 'unknown',
      rows: rawRows
          .whereType<Map<String, dynamic>>()
          .map(DipstickResultRow.fromJson)
          .toList(),
      padsDetected: (json['padsDetected'] as num?)?.toInt(),
      padsUnavailable: (json['padsUnavailable'] as num?)?.toInt(),
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
