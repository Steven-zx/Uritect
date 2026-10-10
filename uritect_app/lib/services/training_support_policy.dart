import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/scan_model.dart';
import '../models/scan_analysis_failure.dart';

/// Absolute feature distance, independent of the neighbour vote agreement.
/// This training-only envelope has not been clinically calibrated.
class TrainingSupportPolicy {
  final Map<String, double> radii;
  const TrainingSupportPolicy._(this.radii);
  factory TrainingSupportPolicy.fromText(String modelText, String policyText) {
    final model = jsonDecode(modelText) as Map<String, dynamic>;
    final policy = jsonDecode(policyText) as Map<String, dynamic>;
    if (policy['schema'] != 1 ||
        policy['model_sha256'] !=
            sha256.convert(utf8.encode(modelText)).toString() ||
        policy['method'] !=
            'max_leave_one_distinct_training_vector_out_nearest_distance') {
      throw StateError(
        'The model support policy does not match the installed model.',
      );
    }
    final entries = policy['analytes'] as Map<String, dynamic>;
    final models = model['analytes'] as Map<String, dynamic>;
    if (entries.length != 10 ||
        models.length != 10 ||
        !entries.keys.toSet().containsAll(ScanResult.expectedAnalytes.values)) {
      throw StateError('The model support policy is incomplete.');
    }
    final radii = <String, double>{};
    for (final name in ScanResult.expectedAnalytes.values) {
      final entry = entries[name] as Map<String, dynamic>;
      final spec = models[name] as Map<String, dynamic>;
      final vectors = spec['train_vectors'] as List;
      final radius = (entry['maximum_distance'] as num).toDouble();
      if (!radius.isFinite ||
          radius <= 0 ||
          vectors.isEmpty ||
          entry['metric'] != spec['metric'] ||
          vectors.any((v) => v is! List || v.length != entry['dimensions'])) {
        throw StateError('Invalid model support policy for $name.');
      }
      radii[name] = radius;
    }
    return TrainingSupportPolicy._(radii);
  }
  void validate(String analyte, double distance) {
    final radius = radii[analyte];
    if (radius == null ||
        !distance.isFinite ||
        distance < 0 ||
        distance > radius) {
      throw ScanAnalysisFailure(
        code: 'OUTSIDE_TRAINING_SUPPORT',
        padsDetected: 10,
        guidance:
            'All ten pads were located, but the $analyte colors are outside the model’s observed training range. Retake with even lighting. If this persists, use the strip’s manufacturer instructions and laboratory review.',
      );
    }
  }
}
