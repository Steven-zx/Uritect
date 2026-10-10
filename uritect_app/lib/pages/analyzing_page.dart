import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../models/scan_analysis_failure.dart';
import '../models/scan_provenance.dart';
import '../services/scan_analysis_service.dart';
import '../widgets/strip_analysis_animation.dart';
import 'results_page.dart';

class AnalyzingPage extends StatefulWidget {
  final String imagePath;
  final ScanAnalysisService analysisService;
  final ScanProvenance? provenance;

  const AnalyzingPage({
    super.key,
    required this.imagePath,
    this.analysisService = const ScanAnalysisService(),
    this.provenance,
  });

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage> {
  ScanLocalization? _localization;
  String _currentStage = 'starting';
  late Future<ScanResult> _scanResultFuture;

  @override
  void initState() {
    super.initState();
    _scanResultFuture = widget.analysisService.analyze(
      imagePath: widget.imagePath,
      onLocalization: (localization) {
        if (mounted) setState(() => _localization = localization);
      },
      onProgress: (progress, stage) {
        if (!mounted) return;
        setState(() {
          _currentStage = stage;
        });
      },
    );
    _scanResultFuture
        .then((scanResult) async {
          if (!mounted) return;
          setState(() {
            _currentStage = 'complete';
          });
          await _showResults(scanResult);
        })
        .catchError((error) async {
          if (!mounted) return;
          if (_isInvalidScanError(error)) {
            debugPrint('URITECT scan rejected: $error');
            final failure = ScanAnalysisFailure.fromError(error);
            final invalidResult =
                ScanResult.empty(
                  imagePath: widget.imagePath,
                  id: 'invalid_${DateTime.now().millisecondsSinceEpoch}',
                ).copyWith(
                  status: 'invalid',
                  riskBucket: 'Unavailable',
                  modelVersion:
                      'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
                  padsDetected: failure.padsDetected,
                  padsUnavailable: 10,
                  rejectionCode: failure.code,
                  rejectionReason: failure.guidance,
                );
            await _showResults(invalidResult);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan analysis failed: $error')),
          );
          Navigator.of(context).pop();
        });
  }

  // Keep the analysis route alive until results return so the retake reason
  // reaches the capture page instead of completing its push with null.
  Future<void> _showResults(ScanResult result) async {
    final exitReason = await Navigator.of(context).push<ScanAnalysisExitReason>(
      MaterialPageRoute(
        builder: (_) => ResultsPage(
          scanResult: result.copyWith(provenance: widget.provenance),
          localization: _localization,
        ),
      ),
    );
    // Home can remove this route while the results future completes. During
    // the removal animation mounted is still true: never pop the new dashboard.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop(exitReason);
  }

  bool _isInvalidScanError(Object error) {
    if (error is ScanAnalysisFailure) return true;
    final message = error.toString().toLowerCase();
    return message.contains('no_dipstick_found') ||
        message.contains('could not localize enough dipstick pads') ||
        message.contains('no readable dipstick') ||
        message.contains('invalid_image') ||
        message.contains('low_confidence');
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Analyzing your strip',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reading your photo on this device',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: StripAnalysisAnimation(
                        stage: _currentStage,
                        imagePath: widget.imagePath,
                        localization: _localization,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!reduceMotion)
                      SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                          value: _currentStage == 'complete' ? 1 : null,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                          semanticsLabel: 'Analysis in progress',
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      _stageText(_currentStage),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please keep URITECT open while the scan is read.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stageText(String stage) => switch (stage) {
    'loading_production_model' ||
    'loading_reference_map' => 'Loading offline references...',
    'preparing_image' || 'decoding_image' => 'Preparing your photo...',
    'locating_markerless_strip' ||
    'locating_strip' ||
    'locating_marker' => 'Locating the strip and reading its pads...',
    'classifying_pads' => 'Comparing pad colors with offline references...',
    'finalizing_results' => 'Checking the scan results...',
    'complete' => 'Opening your results...',
    _ => 'Preparing the scan...',
  };
}
