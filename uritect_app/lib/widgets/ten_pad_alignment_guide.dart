import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Preview-only positioning aid in the app's existing ten-pad order.
/// This does not define analysis ROIs or change the captured image.
class TenPadAlignmentGuide extends StatelessWidget {
  const TenPadAlignmentGuide({super.key});

  static const labels = [
    'LEU',
    'NIT',
    'URO',
    'PRO',
    'pH',
    'BLD',
    'SG',
    'KET',
    'BIL',
    'GLU',
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final pad = math.min(width * .14, height * .05);
            final step = pad * 1.35;
            final top = height * .11;
            final left = (width - pad) / 2;
            final fontSize = math.min(12.0, pad * .5);
            Widget caption(String text) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xB3123D4A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
            return Stack(
              children: [
                Positioned(
                  top: height * .02,
                  left: 0,
                  right: 0,
                  child: Center(child: caption('Align pads here')),
                ),
                for (var i = 0; i < labels.length; i++) ...[
                  Positioned(
                    top: top + step * i,
                    left: left,
                    width: pad,
                    height: pad,
                    child: Container(
                      key: ValueKey('alignment-pad-$i'),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF0B6F8D),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      foregroundDecoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top + step * i,
                    left: left + pad + 6,
                    height: pad,
                    child: Center(child: caption(labels[i])),
                  ),
                ],
                Positioned(
                  top: top + step * 10 + pad,
                  left: 0,
                  right: 0,
                  child: Center(child: caption('Handle below')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
