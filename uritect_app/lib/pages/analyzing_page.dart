import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'results_page.dart';

class AnalyzingPage extends StatefulWidget {
  final String imagePath;

  const AnalyzingPage({super.key, required this.imagePath});

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  Timer? _transitionTimer;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // Animate from 0 to 100 over 3 seconds
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 100.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutQuad),
    );

    _progressAnimation.addListener(() {
      setState(() {
        _currentProgress = _progressAnimation.value;
      });
    });

    _progressController.forward();

    // Transition to results page after animation + 1 second
    _transitionTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ResultsPage(),
          ),
        );
      }
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
                'Analyzing indicators...',
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