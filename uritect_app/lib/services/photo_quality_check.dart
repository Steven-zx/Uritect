import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/scan_analysis_failure.dart';

/// Early engineering checks, not a guarantee that reagent colors are valid.
/// These retain the existing thresholds and run once before pad localization.
class PhotoQualityCheck {
  static void validate(img.Image image) {
    final step = math.max(2, math.max(image.width, image.height) ~/ 180);
    var count = 0;
    var mean = 0.0;
    var varianceSum = 0.0;
    var saturationSum = 0.0;
    var laplacianSum = 0.0;
    for (var y = step; y < image.height - step; y += step) {
      for (var x = step; x < image.width - step; x += step) {
        final p = image.getPixel(x, y);
        final l = _luma(p);
        count++;
        final delta = l - mean;
        mean += delta / count;
        varianceSum += delta * (l - mean);
        final high = math.max(p.r, math.max(p.g, p.b)).toDouble();
        final low = math.min(p.r, math.min(p.g, p.b)).toDouble();
        saturationSum += high == 0 ? 0 : (high - low) / high;
        laplacianSum +=
            (l * 4 -
                    _luma(image.getPixel(x, y - step)) -
                    _luma(image.getPixel(x, y + step)) -
                    _luma(image.getPixel(x + step, y)) -
                    _luma(image.getPixel(x - step, y)))
                .abs();
      }
    }
    if (count == 0) {
      _reject(
        'IMAGE_UNREADABLE',
        'Choose a clear, readable photo of the complete strip.',
      );
    }
    final std = math.sqrt(varianceSum / count);
    if (mean < 28) {
      _reject(
        'IMAGE_TOO_DARK',
        'The photo is too dark. Use even lighting, avoid shadows, and retake.',
      );
    }
    if (mean > 242 && std < 18) {
      _reject(
        'IMAGE_OVEREXPOSED',
        'The photo is overexposed. Reduce glare and move away from direct light.',
      );
    }
    if (std < 6 && saturationSum / count < .035) {
      _reject(
        'IMAGE_BLANK',
        'No clear strip signal is visible. Show the complete strip on a plain background.',
      );
    }
    if (laplacianSum / count < 2.8) {
      _reject(
        'IMAGE_BLURRED',
        'The photo is blurred. Tap the pads to focus and hold the phone steady.',
      );
    }
  }

  static Never _reject(String code, String guidance) =>
      throw ScanAnalysisFailure(code: code, guidance: guidance);
  static double _luma(img.Pixel p) => .2126 * p.r + .7152 * p.g + .0722 * p.b;
}
