import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Shared, testable runtime color math. No detector or classifier decisions.
class RuntimePadFeatures {
  static Map<String, List<double>> normalizeHsv(Map<String, List<double>> raw) {
    if (raw.isEmpty) return {};
    var sinH = 0.0, cosH = 0.0, sumS = 0.0, sumV = 0.0;
    for (final hsv in raw.values) {
      sinH += math.sin(hsv[0] * math.pi / 180);
      cosH += math.cos(hsv[0] * math.pi / 180);
      sumS += hsv[1];
      sumV += hsv[2];
    }
    final anchor = normalizeHue(math.atan2(sinH, cosH) * 180 / math.pi);
    return raw.map(
      (name, hsv) => MapEntry(name, [
        normalizeHue(hsv[0] - anchor),
        (.5 + (hsv[1] - sumS / raw.length)).clamp(0.0, 1.0).toDouble(),
        (.5 + (hsv[2] - sumV / raw.length)).clamp(0.0, 1.0).toDouble(),
      ]),
    );
  }

  static List<double> meanHsv(
    img.Image image, {
    required int left,
    required int top,
    required int width,
    required int height,
    required List<double> rgbGains,
  }) {
    if (left < 0 ||
        top < 0 ||
        width < 1 ||
        height < 1 ||
        left + width > image.width ||
        top + height > image.height ||
        rgbGains.length != 3 ||
        rgbGains.any((v) => !v.isFinite || v <= 0)) {
      throw ArgumentError('Invalid pad ROI or correction gains');
    }
    var sinH = 0.0;
    var cosH = 0.0;
    var sumS = 0.0;
    var sumV = 0.0;
    var count = 0;
    final step = math.max(1, math.min(width, height) ~/ 12);
    for (var y = top; y < top + height; y += step) {
      for (var x = left; x < left + width; x += step) {
        final pixel = image.getPixel(x, y);
        final hsv = rgbToHsv(
          (pixel.r.toDouble() * rgbGains[0]).clamp(0.0, 255.0).toDouble(),
          (pixel.g.toDouble() * rgbGains[1]).clamp(0.0, 255.0).toDouble(),
          (pixel.b.toDouble() * rgbGains[2]).clamp(0.0, 255.0).toDouble(),
        );
        sinH += math.sin(hsv[0] * math.pi / 180.0);
        cosH += math.cos(hsv[0] * math.pi / 180.0);
        sumS += hsv[1];
        sumV += hsv[2];
        count++;
      }
    }
    return [
      normalizeHue(math.atan2(sinH, cosH) * 180 / math.pi),
      sumS / count,
      sumV / count,
    ];
  }

  static List<double> rgbToHsv(double r, double g, double b) {
    final rn = r / 255.0, gn = g / 255.0, bn = b / 255.0;
    final maximum = math.max(rn, math.max(gn, bn));
    final minimum = math.min(rn, math.min(gn, bn));
    final delta = maximum - minimum;
    var hue = 0.0;
    if (delta != 0) {
      if (maximum == rn) {
        hue = 60.0 * (((gn - bn) / delta) % 6.0);
      } else if (maximum == gn) {
        hue = 60.0 * (((bn - rn) / delta) + 2.0);
      } else {
        hue = 60.0 * (((rn - gn) / delta) + 4.0);
      }
    }
    return [normalizeHue(hue), maximum == 0 ? 0.0 : delta / maximum, maximum];
  }

  static double normalizeHue(double hue) {
    var normalized = hue % 360.0;
    if (normalized < 0) normalized += 360;
    return normalized;
  }
}
