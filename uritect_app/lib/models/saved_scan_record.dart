import 'clinical_symptoms.dart';
import 'scan_model.dart';
import 'screening_fusion.dart';

class SavedScanRecord {
  final String id;
  final DateTime savedAt;
  final ScanResult scanResult;
  final ClinicalChecklistResult checklistResult;
  final String riskBucket;
  final bool hasEvidenceConflict;
  final String? conflictTitle;
  final String? conflictMessage;

  const SavedScanRecord({
    required this.id,
    required this.savedAt,
    required this.scanResult,
    required this.checklistResult,
    required this.riskBucket,
    this.hasEvidenceConflict = false,
    this.conflictTitle,
    this.conflictMessage,
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
      riskBucket: fusionResult.riskBucket,
      hasEvidenceConflict: fusionResult.hasEvidenceConflict,
      conflictTitle: fusionResult.conflictTitle,
      conflictMessage: fusionResult.conflictMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'savedAt': savedAt.toIso8601String(),
      'scanResult': scanResult.toJson(),
      'checklistResult': checklistResult.toJson(),
      'riskBucket': riskBucket,
      'hasEvidenceConflict': hasEvidenceConflict,
      'conflictTitle': conflictTitle,
      'conflictMessage': conflictMessage,
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
      riskBucket: json['riskBucket'] as String? ?? 'Moderate',
      hasEvidenceConflict: json['hasEvidenceConflict'] == true,
      conflictTitle: json['conflictTitle'] as String?,
      conflictMessage: json['conflictMessage'] as String?,
    );
  }
}
