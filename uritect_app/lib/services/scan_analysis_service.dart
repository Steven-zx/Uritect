import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import 'local_scan_analysis_service.dart';

class ScanAnalysisService {
  const ScanAnalysisService();

  static const LocalScanAnalysisService _localAnalyzer =
      LocalScanAnalysisService();

  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double progress, String stage)? onProgress,
    void Function(ScanLocalization localization)? onLocalization,
  }) {
    return _localAnalyzer.analyze(
      imagePath: imagePath,
      onProgress: onProgress,
      onLocalization: onLocalization,
    );
  }
}
