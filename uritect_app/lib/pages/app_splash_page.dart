import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'root_page.dart';

class AppSplashPage extends StatefulWidget {
  const AppSplashPage({super.key});

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<double> _pulse;
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fade = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0, .25, curve: Curves.easeOutCubic),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.025), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.025, end: 1), weight: 1),
    ]).animate(CurvedAnimation(parent: _motion, curve: Curves.easeInOut));
    // Route timing is independent of animation/accessibility settings.
    _timer = Timer(const Duration(milliseconds: 2200), _openDashboard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _motion.stop();
      _motion.value = 1;
    } else if (!_motion.isAnimating && _motion.value < 1) {
      _motion.forward();
    }
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => const RootPage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF7FCFC),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF22A9BF),
                Color(0xFF76DED5),
                Color(0xFFDDF7F5),
                Color(0xFFF7FCFC),
              ],
              stops: [0, .36, .73, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoSize = math.min(
                  260.0,
                  math.min(
                    constraints.maxWidth * .76,
                    constraints.maxHeight * .46,
                  ),
                );
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: ScaleTransition(
                                    key: const Key('splash-scanner-frame'),
                                    scale: _pulse,
                                    child: const CustomPaint(
                                      painter: _ScannerFramePainter(),
                                    ),
                                  ),
                                ),
                                OverflowBox(
                                  maxWidth: logoSize * 1.35,
                                  maxHeight: logoSize * .80,
                                  child: Image.asset(
                                    'assets/photos/logo.png',
                                    width: logoSize * 1.35,
                                    height: logoSize * .80,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'URITECT',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Preparing offline screening…',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF123D4A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 72,
                            child: AnimatedBuilder(
                              animation: _motion,
                              builder: (context, child) =>
                                  LinearProgressIndicator(
                                    value: _reduceMotion ? 1 : _motion.value,
                                    minHeight: 3,
                                    borderRadius: BorderRadius.circular(3),
                                    color: const Color(0xFF158EAB),
                                    backgroundColor: const Color(0x33158EAB),
                                    semanticsLabel: 'Preparing app',
                                  ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * .065;
    final arm = size.width * .15;
    final paint = Paint()
      ..color = const Color(0xFF0B6F8D)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final corner in [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      final dx = corner.dx < size.width / 2 ? arm : -arm;
      final dy = corner.dy < size.height / 2 ? arm : -arm;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) => false;
}
