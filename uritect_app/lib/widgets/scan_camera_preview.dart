import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ten_pad_alignment_guide.dart';

/// Fills the viewport without stretching, mapping focus into the camera frame.
class ScanCameraPreview extends StatelessWidget {
  final CameraController controller;
  final ValueChanged<Offset> onFocus;
  final bool showAlignmentGuide;

  const ScanCameraPreview({
    super.key,
    required this.controller,
    required this.onFocus,
    this.showAlignmentGuide = false,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CameraValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      if (!value.isInitialized) return const SizedBox.expand();
      final orientation = value.isRecordingVideo
          ? value.recordingOrientation ?? value.deviceOrientation
          : value.previewPauseOrientation ??
                value.lockedCaptureOrientation ??
                value.deviceOrientation;
      final landscape =
          orientation == DeviceOrientation.landscapeLeft ||
          orientation == DeviceOrientation.landscapeRight;
      final ratio = landscape ? value.aspectRatio : 1 / value.aspectRatio;
      return LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          final scale = math.max(viewport.width / ratio, viewport.height);
          final rendered = Size(ratio * scale, scale);
          final origin = Offset(
            (viewport.width - rendered.width) / 2,
            (viewport.height - rendered.height) / 2,
          );
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ratio,
                    height: 1,
                    child: CameraPreview(controller),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => onFocus(
                    Offset(
                      ((details.localPosition.dx - origin.dx) / rendered.width)
                          .clamp(0, 1),
                      ((details.localPosition.dy - origin.dy) / rendered.height)
                          .clamp(0, 1),
                    ),
                  ),
                ),
                if (showAlignmentGuide) const TenPadAlignmentGuide(),
              ],
            ),
          );
        },
      );
    },
  );
}
