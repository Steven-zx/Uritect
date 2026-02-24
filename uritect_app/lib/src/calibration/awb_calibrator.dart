import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'awb_models.dart';

class AwbCalibrator {
  const AwbCalibrator();

  AwbResult applyReferenceWhiteBalance(
    Uint8List encodedImageBytes,
    WhiteReferenceRegion referenceRegion,
  ) {
    final decoded = img.decodeImage(encodedImageBytes);
    if (decoded == null) {
      throw ArgumentError('Unable to decode image bytes for AWB calibration.');
    }

    final normalizedRegion = referenceRegion.normalized();

    final xStart = (normalizedRegion.xNorm * decoded.width).floor();
    final yStart = (normalizedRegion.yNorm * decoded.height).floor();
    final xEnd = max(
      xStart + 1,
      ((normalizedRegion.xNorm + normalizedRegion.widthNorm) * decoded.width).floor(),
    );
    final yEnd = max(
      yStart + 1,
      ((normalizedRegion.yNorm + normalizedRegion.heightNorm) * decoded.height).floor(),
    );

    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    int count = 0;

    for (var y = yStart; y < min(yEnd, decoded.height); y++) {
      for (var x = xStart; x < min(xEnd, decoded.width); x++) {
        final pixel = decoded.getPixel(x, y);
        sumR += pixel.r;
        sumG += pixel.g;
        sumB += pixel.b;
        count++;
      }
    }

    if (count == 0) {
      throw ArgumentError('Reference region did not contain any pixels.');
    }

    final meanR = sumR / count;
    final meanG = sumG / count;
    final meanB = sumB / count;

    final target = (meanR + meanG + meanB) / 3.0;

    final gainR = _safeGain(target, meanR);
    final gainG = _safeGain(target, meanG);
    final gainB = _safeGain(target, meanB);

    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        final correctedR = (pixel.r * gainR).round().clamp(0, 255);
        final correctedG = (pixel.g * gainG).round().clamp(0, 255);
        final correctedB = (pixel.b * gainB).round().clamp(0, 255);

        decoded.setPixelRgba(x, y, correctedR, correctedG, correctedB, pixel.a.round());
      }
    }

    final correctedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));

    return AwbResult(
      correctedBytes: correctedBytes,
      gainR: gainR,
      gainG: gainG,
      gainB: gainB,
      referenceMeanR: meanR,
      referenceMeanG: meanG,
      referenceMeanB: meanB,
    );
  }

  double _safeGain(double target, double channelMean) {
    if (channelMean <= 0.0001) {
      return 1.0;
    }
    return target / channelMean;
  }
}
