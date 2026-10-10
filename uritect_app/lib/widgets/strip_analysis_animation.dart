import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/scan_localization.dart';

/// Animates real sampling regions; no timer creates detection evidence.
class StripAnalysisAnimation extends StatefulWidget {
  final String stage;
  final String? imagePath;
  final ScanLocalization? localization;
  const StripAnalysisAnimation({
    super.key,
    required this.stage,
    this.imagePath,
    this.localization,
  });
  @override
  State<StripAnalysisAnimation> createState() => _StripAnalysisAnimationState();
}

class _StripAnalysisAnimationState extends State<StripAnalysisAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _active = true;
  bool _reduceMotion = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_active && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _updateAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evidence = widget.localization;
    final located = evidence?.regions.isNotEmpty == true;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              located ? 'Your pad sampling regions' : 'Your strip photo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Semantics(
              image: true,
              label: located
                  ? 'Actual photo with ${evidence!.regions.length} detector sampling regions. Localization is not a valid result.'
                  : 'Submitted photo. No confirmed sampling regions yet.',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 0.9,
                    child: ColoredBox(
                      color: const Color(0xFFEAF7F9),
                      child: evidence == null
                          ? const Center(
                              child: Text('Preparing photo preview...'),
                            )
                          : Image.memory(
                              evidence.preview,
                              key: ValueKey(evidence.preview),
                              fit: BoxFit.contain,
                              gaplessPlayback: false,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text('Photo preview unavailable'),
                              ),
                              frameBuilder: (context, child, frame, synchronous) {
                                // Never paint new coordinates over a stale rotated frame.
                                if (frame == null && !synchronous) return child;
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    child,
                                    if (located)
                                      AnimatedBuilder(
                                        animation: _controller,
                                        builder: (_, _) => CustomPaint(
                                          key: const ValueKey(
                                            'actual-pad-overlay',
                                          ),
                                          painter: SampleRegionPainter(
                                            evidence,
                                            _reduceMotion
                                                ? 1
                                                : _controller.value,
                                            Theme.of(
                                                  context,
                                                ).textTheme.labelSmall ??
                                                const TextStyle(),
                                          ),
                                        ),
                                      )
                                    else if (!_reduceMotion)
                                      AnimatedBuilder(
                                        animation: _controller,
                                        builder: (_, _) => CustomPaint(
                                          painter: _PhotoSearchPainter(
                                            evidence.imageSize,
                                            _controller.value,
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
              ),
            ),
            const SizedBox(height: 12),
            Text(
              located
                  ? '${evidence!.regions.length} sampling regions located'
                  : 'Locating the strip. Regions appear when confirmed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Outlines show color samples, not clinical results.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF47717B)),
            ),
          ],
        ),
      ),
    );
  }
}

class SampleRegionPainter extends CustomPainter {
  final ScanLocalization localization;
  final double phase;
  final TextStyle labelStyle;
  SampleRegionPainter(this.localization, this.phase, this.labelStyle);
  @override
  void paint(Canvas canvas, Size size) {
    final image = localization.imageSize;
    final active = math.min(
      localization.regions.length - 1,
      (phase * localization.regions.length).floor(),
    );
    for (var i = 0; i < localization.regions.length; i++) {
      final region = localization.regions[i];
      final rect = displayedSampleRect(region.rect, image, size);
      // All boxes are measured; the moving highlight is a visual explanation.
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF0B6F8D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      if (i == active) {
        canvas.drawRect(
          rect,
          Paint()..color = const Color(0xFF22A9BF).withValues(alpha: 0.35),
        );
      }
      final label = TextPainter(
        text: TextSpan(
          text: region.label,
          style: labelStyle.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (rect.right + 5).clamp(
        3.0,
        math.max(3.0, size.width - label.width - 7),
      );
      final top = rect.center.dy - label.height / 2;
      final background = Rect.fromLTWH(
        left - 3,
        top - 2,
        label.width + 6,
        label.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(background, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0B6F8D),
      );
      label.paint(canvas, Offset(left.toDouble(), top));
    }
  }

  @override
  bool shouldRepaint(SampleRegionPainter oldDelegate) =>
      oldDelegate.localization != localization || oldDelegate.phase != phase;
}

/// An illustrative search sweep, never a measured boundary or progress value.
class _PhotoSearchPainter extends CustomPainter {
  final Size image;
  final double phase;
  _PhotoSearchPainter(this.image, this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final photo = containedPhotoRect(image, size);
    final y = photo.top + phase * photo.height;
    canvas.drawLine(
      Offset(photo.left, y),
      Offset(photo.right, y),
      Paint()
        ..color = const Color(0xFF22A9BF).withValues(alpha: 0.7)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PhotoSearchPainter old) =>
      old.phase != phase || old.image != image;
}
