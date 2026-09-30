import '../models/scan_model.dart';
import 'local_scan_analysis_service.dart';

class ScanAnalysisService {
  const ScanAnalysisService();

  static const LocalScanAnalysisService _localAnalyzer =
      LocalScanAnalysisService();

  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double progress, String stage)? onProgress,
  }) {
    return _localAnalyzer.analyze(imagePath: imagePath, onProgress: onProgress);
  }
}
