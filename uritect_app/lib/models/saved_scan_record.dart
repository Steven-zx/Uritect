import 'clinical_symptoms.dart';
import 'scan_model.dart';
import 'screening_fusion.dart';

class SavedScanRecord {
  final String id;
  final DateTime savedAt;
  final ScanResult scanResult;
  final ClinicalChecklistResult checklistResult;
  final double posteriorProbability;
  final String riskBucket;
  final double clinicalLogOddsContribution;

  const SavedScanRecord({
    required this.id,
    required this.savedAt,
    required this.scanResult,
    required this.checklistResult,
    required this.posteriorProbability,
    required this.riskBucket,
    required this.clinicalLogOddsContribution,
  });

  factory SavedScanRecord.fromAnalysis({
    required ScanResult scanResult,
    required ClinicalChecklistResult checklistResult,
    required ScreeningFusionResult fusionResult,
  }) {
    return SavedScanRecord(
      id: scanResult.id,
      savedAt: DateTime.now(),
      scanResult: scanResult,
      checklistResult: checklistResult,
      posteriorProbability: fusionResult.posteriorProbability,
      riskBucket: fusionResult.riskBucket,
      clinicalLogOddsContribution: fusionResult.logOddsContribution,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'savedAt': savedAt.toIso8601String(),
      'scanResult': scanResult.toJson(),
      'checklistResult': checklistResult.toJson(),
      'posteriorProbability': posteriorProbability,
      'riskBucket': riskBucket,
      'clinicalLogOddsContribution': clinicalLogOddsContribution,
    };
  }

  factory SavedScanRecord.fromJson(Map<String, dynamic> json) {
    return SavedScanRecord(
      id: json['id'] as String? ?? 'scan_missing',
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      scanResult: ScanResult.fromJson(
        json['scanResult'] as Map<String, dynamic>? ?? const {},
      ),
      checklistResult: ClinicalChecklistResult.fromJson(
        json['checklistResult'] as Map<String, dynamic>? ?? const {},
      ),
      posteriorProbability:
          (json['posteriorProbability'] as num?)?.toDouble() ?? 0.0,
      riskBucket: json['riskBucket'] as String? ?? 'Moderate',
      clinicalLogOddsContribution:
          (json['clinicalLogOddsContribution'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
