import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan_model.dart';
import '../services/scan_analysis_service.dart';
import 'results_page.dart';

class AnalyzingPage extends StatefulWidget {
  final String imagePath;

  const AnalyzingPage({super.key, required this.imagePath});

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage> with TickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _transitionTimer;
  double _currentProgress = 0.0;
  String _currentStage = 'starting';
  late Future<ScanResult> _scanResultFuture;
  final ScanAnalysisService _scanAnalysisService = const ScanAnalysisService();
  bool _animationInProgress = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _progressController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentProgress = _progressController.value * 100.0;
      });
    });

    _scanResultFuture = _scanAnalysisService.analyze(
      imagePath: widget.imagePath,
      onProgress: (progress, stage) {
        if (!mounted) return;
        setState(() {
          _currentStage = stage;
        });
        final safeTarget = (progress / 100.0).clamp(0.0, 1.0).toDouble();
        if (_animationInProgress || safeTarget <= _progressController.value) {
          return;
        }
        _animationInProgress = true;
        _progressController.animateTo(
          safeTarget,
          duration: Duration(milliseconds: (150 + (safeTarget * 200)).round()),
          curve: Curves.easeOut,
        ).then((_) {
          _animationInProgress = false;
        }).catchError((_) {
          _animationInProgress = false;
        });
      },
    );
    _scanResultFuture.then((scanResult) async {
      if (!mounted) return;
      _animationInProgress = true;
      await _progressController.animateTo(1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      if (!mounted) return;
      _animationInProgress = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultsPage(scanResult: scanResult)),
      );
    }).catchError((error) {
      _animationInProgress = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan analysis failed: $error')),
      );
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _transitionTimer?.cancel();
    super.dispose();
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
                'Please wait while we analyze\nthe dipstick and related data',
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
                _currentStage == 'complete' ? 'Finalizing result...' : 'Analyzing $_currentStage...',
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