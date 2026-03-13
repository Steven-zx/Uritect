import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'awb_models.dart';

class MacroMarkerDetection {
  const MacroMarkerDetection({
    required this.centerNormalized,
    required this.innerRadiusNormalized,
    required this.confidence,
  });

  final Offset centerNormalized;
  final double innerRadiusNormalized;
  final double confidence;

  WhiteReferenceRegion get whiteCenterRegion {
    final safeRadius = innerRadiusNormalized.clamp(0.01, 0.3);
    final squareSide = (safeRadius * 1.1).clamp(0.02, 0.4);
    final half = squareSide / 2;

    final xNorm = (centerNormalized.dx - half).clamp(0.0, 1.0);
    final yNorm = (centerNormalized.dy - half).clamp(0.0, 1.0);

    final widthNorm = math.min(squareSide, 1.0 - xNorm);
    final heightNorm = math.min(squareSide, 1.0 - yNorm);

    return WhiteReferenceRegion(
      xNorm: xNorm,
      yNorm: yNorm,
      widthNorm: widthNorm,
      heightNorm: heightNorm,
    );
  }
}

class MacroMarkerDetector {
  const MacroMarkerDetector();

  MacroMarkerDetection? detect(Uint8List encodedImageBytes) {
    final decoded = img.decodeImage(encodedImageBytes);
    if (decoded == null) {
      return null;
    }

    final working = _resizeForSearch(decoded);
    final minDim = math.min(working.width, working.height).toDouble();

    final candidateRadii = <int>[
      (minDim * 0.018).round(),
      (minDim * 0.024).round(),
      (minDim * 0.030).round(),
      (minDim * 0.036).round(),
    ].where((radius) => radius >= 4).toSet().toList()..sort();

    if (candidateRadii.isEmpty) {
      return null;
    }

    final stride = math.max(4, (minDim / 120).round());

    _BestCandidate? best;

    for (final radius in candidateRadii) {
      final outerRadius = (radius * 1.8).round();
      final margin = outerRadius + 2;

      for (var y = margin; y < working.height - margin; y += stride) {
        for (var x = margin; x < working.width - margin; x += stride) {
          final innerMean = _sampleDiskMeanBrightness(
            image: working,
            centerX: x,
            centerY: y,
            radius: radius * 0.55,
            radialSteps: 3,
            angularSteps: 12,
          );

          final ringMean = _sampleAnnulusMeanBrightness(
            image: working,
            centerX: x,
            centerY: y,
            innerRadius: radius * 1.05,
            outerRadius: radius * 1.75,
            radialSteps: 3,
            angularSteps: 24,
          );

          final contrast = innerMean - ringMean;

          if (innerMean < 150 || ringMean > 140 || contrast < 35) {
            continue;
          }

          final score = contrast + ((160 - ringMean).clamp(0, 120) * 0.35);

          if (best == null || score > best.score) {
            best = _BestCandidate(
              x: x.toDouble(),
              y: y.toDouble(),
              innerRadius: radius.toDouble(),
              score: score,
            );
          }
        }
      }
    }

    if (best == null || best.score < 45) {
      return null;
    }

    final normalizedCenter = Offset(
      best.x / working.width,
      best.y / working.height,
    );

    final normalizedRadius = best.innerRadius / minDim;
    final confidence = ((best.score - 45) / 85).clamp(0.0, 1.0);

    return MacroMarkerDetection(
      centerNormalized: normalizedCenter,
      innerRadiusNormalized: normalizedRadius,
      confidence: confidence,
    );
  }

  img.Image _resizeForSearch(img.Image source) {
    const maxDim = 900;
    final longest = math.max(source.width, source.height);
    if (longest <= maxDim) {
      return source;
    }

    final scale = maxDim / longest;
    final targetWidth = (source.width * scale).round();
    final targetHeight = (source.height * scale).round();

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }

  double _sampleDiskMeanBrightness({
    required img.Image image,
    required double centerX,
    required double centerY,
    required double radius,
    required int radialSteps,
    required int angularSteps,
  }) {
    var sum = 0.0;
    var count = 0;

    for (var radialStep = 0; radialStep < radialSteps; radialStep++) {
      final r = radius * ((radialStep + 1) / radialSteps);
      for (var angularStep = 0; angularStep < angularSteps; angularStep++) {
        final theta = (2 * math.pi * angularStep) / angularSteps;
        final x = (centerX + r * math.cos(theta)).round().clamp(0, image.width - 1);
        final y = (centerY + r * math.sin(theta)).round().clamp(0, image.height - 1);

        final pixel = image.getPixel(x, y);
        sum += (pixel.r + pixel.g + pixel.b) / 3.0;
        count++;
      }
    }

    final centerPixel = image.getPixel(
      centerX.round().clamp(0, image.width - 1),
      centerY.round().clamp(0, image.height - 1),
    );
    sum += (centerPixel.r + centerPixel.g + centerPixel.b) / 3.0;
    count++;

    return count == 0 ? 0 : sum / count;
  }

  double _sampleAnnulusMeanBrightness({
    required img.Image image,
    required double centerX,
    required double centerY,
    required double innerRadius,
    required double outerRadius,
    required int radialSteps,
    required int angularSteps,
  }) {
    var sum = 0.0;
    var count = 0;

    for (var radialStep = 0; radialStep < radialSteps; radialStep++) {
      final t = (radialStep + 1) / radialSteps;
      final r = innerRadius + ((outerRadius - innerRadius) * t);

      for (var angularStep = 0; angularStep < angularSteps; angularStep++) {
        final theta = (2 * math.pi * angularStep) / angularSteps;
        final x = (centerX + r * math.cos(theta)).round().clamp(0, image.width - 1);
        final y = (centerY + r * math.sin(theta)).round().clamp(0, image.height - 1);

        final pixel = image.getPixel(x, y);
        sum += (pixel.r + pixel.g + pixel.b) / 3.0;
        count++;
      }
    }

    return count == 0 ? 255 : sum / count;
  }
}

class _BestCandidate {
  const _BestCandidate({
    required this.x,
    required this.y,
    required this.innerRadius,
    required this.score,
  });

  final double x;
  final double y;
  final double innerRadius;
  final double score;
}
