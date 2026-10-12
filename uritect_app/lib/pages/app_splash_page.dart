import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'root_page.dart';

/// Brief launch branding; no analysis or medical result is implied.
class AppSplashPage extends StatefulWidget {
  const AppSplashPage({super.key});

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final reduced = MediaQuery.disableAnimationsOf(context);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration(milliseconds: reduced ? 0 : 300),
          pageBuilder: (_, animation, secondaryAnimation) => const RootPage(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
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
                final size = math
                    .min(
                      constraints.maxWidth * .62,
                      constraints.maxHeight * .36,
                    )
                    .clamp(100.0, 420.0);
                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -.14),
                      child: SizedBox.square(
                        dimension: size,
                        child: CustomPaint(
                          painter: const _ScannerCorners(),
                          child: Padding(
                            padding: EdgeInsets.all(size * .08),
                            child: ClipRect(
                              child: Image.asset(
                                'assets/photos/logo.png',
                                fit: BoxFit.cover,
                                semanticLabel: 'URITECT',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, .39),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Preparing offline screening…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF123D4A),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 76,
                              child: LinearProgressIndicator(
                                value: reduced ? .85 : null,
                                minHeight: 3,
                                borderRadius: BorderRadius.circular(3),
                                color: const Color(0xFF158EAB),
                                backgroundColor: const Color(0xFFAFDFE1),
                                semanticsLabel: 'Preparing app',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerCorners extends CustomPainter {
  const _ScannerCorners();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B6F8D)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arm = size.width * .17;
    for (final corner in [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = corner.dx == 0 ? arm : -arm;
      final dy = corner.dy == 0 ? arm : -arm;
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
  bool shouldRepaint(_ScannerCorners oldDelegate) => false;
}
