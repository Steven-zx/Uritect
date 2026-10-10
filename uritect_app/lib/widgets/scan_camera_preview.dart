import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'ten_pad_alignment_guide.dart';

/// Shows the complete camera view, with focus coordinates relative to that view.
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
  Widget build(BuildContext context) {
    return Center(
      child: CameraPreview(
        controller,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => onFocus(
                  Offset(
                    (details.localPosition.dx / constraints.maxWidth).clamp(
                      0,
                      1,
                    ),
                    (details.localPosition.dy / constraints.maxHeight).clamp(
                      0,
                      1,
                    ),
                  ),
                ),
              ),
              if (showAlignmentGuide) const TenPadAlignmentGuide(),
            ],
          ),
        ),
      ),
    );
  }
}
