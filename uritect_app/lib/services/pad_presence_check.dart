import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Dataset-derived engineering check for a sampling box placed on background.
/// It establishes neither a reference category nor clinical strip validity.
class PadPresenceCheck {
  static bool isSupported(
    img.Image image, {
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    if (left < 0 ||
        top < 0 ||
        width < 1 ||
        height < 1 ||
        left + width > image.width ||
        top + height > image.height) {
      return false;
    }
    final step = math.max(1, math.min(width, height) ~/ 12);
    final references = <List<double>>[];
    final referenceX = <double>[];
    for (final interval in [
      [math.max(0, left - 4 * width), math.max(0, left - 2 * width)],
      [
        math.min(image.width, left + 3 * width),
        math.min(image.width, left + 5 * width),
      ],
    ]) {
      final samples = <List<double>>[];
      for (var y = top; y < top + height; y += step) {
        for (var x = interval[0]; x < interval[1]; x += step) {
          samples.add(_lab(image.getPixel(x, y)));
        }
      }
      if (samples.isNotEmpty) {
        referenceX.add((interval[0] + interval[1] - 1) / 2);
        references.add([
          for (var channel = 0; channel < 3; channel++)
            _median([for (final sample in samples) sample[channel]]),
        ]);
      }
    }
    if (references.isEmpty) return false;
    if (references.length == 2) {
      final fraction =
          ((left + width / 2 - referenceX[0]) / (referenceX[1] - referenceX[0]))
              .clamp(0.0, 1.0);
      // A smooth lighting gradient is background too. Keeping the individual
      // references prevents a marker on one side from manufacturing contrast.
      references.add([
        for (var c = 0; c < 3; c++)
          references[0][c] * (1 - fraction) + references[1][c] * fraction,
      ]);
    }
    var separated = 0, count = 0;
    for (var y = top; y < top + height; y += step) {
      for (var x = left; x < left + width; x += step) {
        final observed = _lab(image.getPixel(x, y));
        // Keep left/right references separate. A dark marker on one side
        // must not make ordinary background look like a reagent pad.
        final distanceSquared = references
            .map((reference) {
              var distance = 0.0;
              for (var channel = 0; channel < 3; channel++) {
                final delta = observed[channel] - reference[channel];
                distance += delta * delta;
              }
              return distance;
            })
            .reduce(math.min);
        if (distanceSquared > 9) separated++;
        count++;
      }
    }
    return count > 0 && separated / count >= .95;
  }

  static bool hasPersistentStripEdge(
    img.Image image, {
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    final step = math.max(1, height ~/ 12);
    final x0 = math.max(2, left - width);
    final x1 = math.min(image.width - 3, left + width * 2);
    for (var x = x0; x <= x1; x++) {
      var strong = 0, count = 0;
      for (var y = top; y < top + height; y += step) {
        var distance = 0.0;
        for (var c = 0; c < 3; c++) {
          double channel(img.Pixel p) => c == 0
              ? p.r.toDouble()
              : c == 1
              ? p.g.toDouble()
              : p.b.toDouble();
          final before =
              (channel(image.getPixel(x - 2, y)) +
                  channel(image.getPixel(x - 1, y))) /
              2;
          final after =
              (channel(image.getPixel(x + 1, y)) +
                  channel(image.getPixel(x + 2, y))) /
              2;
          final delta = after - before;
          distance += delta * delta;
        }
        if (distance >= 18 * 18) strong++;
        count++;
      }
      if (count > 0 && strong / count >= .65) return true;
    }
    return false;
  }

  static List<double> _lab(img.Pixel pixel) {
    final lab = img.rgbToLab(pixel.r, pixel.g, pixel.b);
    return [
      (lab[0] * 255 / 100).round().clamp(0, 255).toDouble(),
      (lab[1] + 128).round().clamp(0, 255).toDouble(),
      (lab[2] + 128).round().clamp(0, 255).toDouble(),
    ];
  }

  static double _median(List<double> values) {
    values.sort();
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }
}
