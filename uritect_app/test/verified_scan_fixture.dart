import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/scan_provenance.dart';

/// Synthetic evidence for positive rule/UI tests, not real specimen validation.
ScanResult verifiedFixture(ScanResult scan) => scan.copyWith(
  modelVersion: 'synthetic_verified_rule_fixture',
  padsDetected: scan.status == 'invalid' ? 0 : 10,
  padsUnavailable: scan.status == 'invalid' ? 10 : 0,
  analyteConfidences: {
    for (final name in ScanResult.expectedAnalytes.values) name: .91,
  },
  stripDirectionVerified: true,
  modelDirectionReviewed: true,
  supportCheckPassed: true,
  nearestTrainingDistances: {
    for (final name in ScanResult.expectedAnalytes.values) name: 0,
  },
  provenance: ScanProvenance(
    source: 'camera',
    analyzedAt: scan.date,
    capturedAt: scan.date,
    contentSha256: 'a' * 64,
    pixelSha256: 'b' * 64,
    imageFingerprint: 'c' * 16,
    specimenCode: 'SYNTHETIC_TEST',
    secondsAfterDipping: 60,
    currentSpecimenConfirmed: true,
    duplicateCheckCompleted: true,
  ),
);
