import 'dart:ui';

import 'package:flutter/material.dart';

class StripFramingGeometry {
  const StripFramingGeometry({
    required this.canvasSize,
    required this.cutoutRect,
    required this.roiRects,
  });

  final Size canvasSize;
  final Rect cutoutRect;
  final List<Rect> roiRects;

  List<Offset> get roiCenters => roiRects.map((rect) => rect.center).toList(growable: false);

  List<Offset> normalizedRoiCenters() {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      return const [];
    }

    return roiCenters
        .map(
          (center) => Offset(
            center.dx / canvasSize.width,
            center.dy / canvasSize.height,
          ),
        )
        .toList(growable: false);
  }
}

class StripFramingOverlay extends StatelessWidget {
  const StripFramingOverlay({
    super.key,
    this.roiCount = 10,
    this.onGeometryChanged,
    this.overlayOpacity = 0.55,
  });

  final int roiCount;
  final ValueChanged<StripFramingGeometry>? onGeometryChanged;
  final double overlayOpacity;

  static StripFramingGeometry computeGeometry({
    required Size size,
    int roiCount = 10,
  }) {
    final safeRoiCount = roiCount < 1 ? 1 : roiCount;

    final cutoutWidth = size.width * 0.28;
    final cutoutHeight = size.height * 0.76;

    final cutoutRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cutoutWidth,
      height: cutoutHeight,
    );

    final verticalPadding = cutoutRect.height * 0.05;
    final usableHeight = cutoutRect.height - (2 * verticalPadding);
    final slotHeight = usableHeight / safeRoiCount;
    final roiSize = slotHeight * 0.62;

    final roiRects = List<Rect>.generate(safeRoiCount, (index) {
      final centerY = cutoutRect.top + verticalPadding + (slotHeight * index) + (slotHeight / 2);
      final centerX = cutoutRect.center.dx;
      return Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: roiSize,
        height: roiSize,
      );
    }, growable: false);

    return StripFramingGeometry(
      canvasSize: size,
      cutoutRect: cutoutRect,
      roiRects: roiRects,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = computeGeometry(size: size, roiCount: roiCount);

        if (onGeometryChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onGeometryChanged!(geometry);
          });
        }

        return CustomPaint(
          painter: _StripFramingOverlayPainter(
            geometry: geometry,
            overlayOpacity: overlayOpacity,
          ),
          size: size,
        );
      },
    );
  }
}

class _StripFramingOverlayPainter extends CustomPainter {
  const _StripFramingOverlayPainter({
    required this.geometry,
    required this.overlayOpacity,
  });

  final StripFramingGeometry geometry;
  final double overlayOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: overlayOpacity);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(geometry.cutoutRect, const Radius.circular(12)),
      clearPaint,
    );

    canvas.restore();

    final cutoutBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(geometry.cutoutRect, const Radius.circular(12)),
      cutoutBorderPaint,
    );

    final roiPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var index = 0; index < geometry.roiRects.length; index++) {
      final rect = geometry.roiRects[index];
      canvas.drawRect(rect, roiPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(rect.right + 4, rect.center.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripFramingOverlayPainter oldDelegate) {
    return oldDelegate.geometry != geometry || oldDelegate.overlayOpacity != overlayOpacity;
  }
}
