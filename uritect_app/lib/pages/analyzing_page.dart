import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../models/scan_model.dart';
import '../services/scan_analysis_service.dart';
import 'results_page.dart';

class AnalyzingPage extends StatefulWidget {
  final String imagePath;

  const AnalyzingPage({super.key, required this.imagePath});

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage> {
  Timer? _progressTimer;
  double _currentProgress = 1.0;
  double _targetProgress = 8.0;
  String _currentStage = 'starting';
  late Future<ScanResult> _scanResultFuture;
  final ScanAnalysisService _scanAnalysisService = const ScanAnalysisService();

  @override
  void initState() {
    super.initState();
    _startProgressLoop();

    _scanResultFuture = _scanAnalysisService.analyze(
      imagePath: widget.imagePath,
      onProgress: (progress, stage) {
        if (!mounted) return;
        setState(() {
          _currentStage = stage;
          _targetProgress = _stageTarget(progress, stage);
        });
      },
    );
    _scanResultFuture
        .then((scanResult) async {
          if (!mounted) return;
          setState(() {
            _currentStage = 'complete';
            _targetProgress = 100.0;
          });
          await _finishProgress();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResultsPage(scanResult: scanResult),
            ),
          );
        })
        .catchError((error) {
          if (!mounted) return;
          if (_isNoDipstickError(error)) {
            Navigator.of(context).pop(ScanAnalysisExitReason.noDipstickFound);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan analysis failed: $error')),
          );
          Navigator.of(context).pop();
        });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressLoop() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _currentProgress >= _targetProgress) {
        return;
      }

      final distance = _targetProgress - _currentProgress;
      final step = distance > 35
          ? 1.6
          : distance > 15
          ? 1.0
          : distance > 4
          ? 0.45
          : 0.16;
      setState(() {
        _currentProgress = (_currentProgress + step).clamp(
          1.0,
          _targetProgress,
        );
      });
    });
  }

  Future<void> _finishProgress() async {
    while (mounted && _currentProgress < 100.0) {
      setState(() {
        _currentProgress = (_currentProgress + 2.5).clamp(1.0, 100.0);
      });
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  double _stageTarget(double reportedProgress, String stage) {
    final reported = reportedProgress.clamp(1.0, 100.0).toDouble();
    final stageTarget = switch (stage) {
      'loading_reference_map' => 18.0,
      'preparing_image' || 'decoding_image' => 32.0,
      'locating_strip' => 95.0,
      'locating_marker' => 95.0,
      'classifying_pads' => 96.0,
      'finalizing_results' => 98.0,
      'complete' => 100.0,
      _ => reported,
    };
    return stageTarget > _targetProgress ? stageTarget : _targetProgress;
  }

  bool _isNoDipstickError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('no_dipstick_found') ||
        message.contains('could not localize enough dipstick pads') ||
        message.contains('no readable dipstick');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Text(
                'Analyzing',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please wait while Uritect reads\nthe dipstick on this device',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular progress indicator
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: _CircularProgressPainter(
                            progress: _currentProgress / 100.0,
                            progressColor: AppColors.primaryMain,
                            backgroundColor: const Color(0xFFE0E0E0),
                            strokeWidth: 12,
                          ),
                        ),
                      ),
                      // Progress percentage text
                      Text(
                        '${_currentProgress.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.primaryMain,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Text(
                _stageText(_currentStage, _currentProgress),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  String _stageText(String stage, double progress) {
    if (stage == 'locating_strip' || stage == 'locating_marker') {
      if (progress < 48) {
        return 'Finding the dipstick strip...';
      }
      if (progress < 66) {
        return 'Locating the reagent pads...';
      }
      if (progress < 82) {
        return 'Reading the reagent pad colors...';
      }
      if (progress < 94) {
        return 'Comparing colors with offline references...';
      }
      return 'Waiting for the final scan result...';
    }

    switch (stage) {
      case 'starting':
        return 'Preparing the scan...';
      case 'loading_reference_map':
        return 'Loading offline reference data...';
      case 'preparing_image':
      case 'decoding_image':
        return 'Preparing the captured image...';
      case 'locating_strip':
        return 'Finding the dipstick strip...';
      case 'locating_marker':
        return 'Finding the dipstick strip...';
      case 'classifying_pads':
        return 'Reading the reagent pad colors...';
      case 'finalizing_results':
      case 'complete':
        return 'Finalizing the dipstick results...';
      default:
        return 'Analyzing the dipstick...';
    }
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -3.14159 / 2; // Start at top
    final sweepAngle = 2 * 3.14159 * progress; // Full circle is 2π

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
