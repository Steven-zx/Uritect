import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/dipstick_results_data.dart';
import '../models/scan_model.dart';

const List<String> _analyteOrder = [
  'Leukocytes',
  'Nitrite',
  'Urobilinogen',
  'Protein',
  'pH',
  'Blood',
  'Specific Gravity',
  'Ketone',
  'Bilirubin',
  'Glucose',
];

const Map<String, String> _referenceRanges = {
  'Leukocytes': 'Negative',
  'Nitrite': 'Negative',
  'Urobilinogen': '3.2 - 128',
  'Protein': 'Negative',
  'pH': '5.0 - 8.5',
  'Blood': 'Negative',
  'Specific Gravity': '1.000 - 1.030',
  'Ketone': 'Negative',
  'Bilirubin': 'Negative',
  'Glucose': 'Negative',
};

class LocalScanAnalysisService {
  const LocalScanAnalysisService();

  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double progress, String stage)? onProgress,
  }) async {
    onProgress?.call(5, 'loading_reference_map');
    final referenceText = await rootBundle.loadString(
      'assets/knn_reference_map.json',
    );

    onProgress?.call(18, 'preparing_image');
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image was not found on this device.');
    }

    onProgress?.call(32, 'locating_strip');
    final resultJson = await Isolate.run(
      () => _analyzeScanInBackground(imagePath, referenceText),
    );

    onProgress?.call(92, 'finalizing_results');
    final scanResult = ScanResult.fromJson(resultJson);
    onProgress?.call(100, 'complete');
    return scanResult;
  }

  img.Image _imageForAnalysis(img.Image image) {
    const maxSide = 900;
    final currentMaxSide = math.max(image.width, image.height);
    if (currentMaxSide <= maxSide) {
      return image;
    }
    final scale = maxSide / currentMaxSide;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  _FeatureExtraction _extractBestPadFeatures(
    img.Image image,
    String featureSpace,
  ) {
    final variants = <_ImageVariant>[
      _ImageVariant('exif', image),
      _ImageVariant('rot90_cw', img.copyRotate(image, angle: 90)),
      _ImageVariant('rot180', img.copyRotate(image, angle: 180)),
      _ImageVariant('rot90_ccw', img.copyRotate(image, angle: -90)),
    ];

    _FeatureExtraction? best;
    for (final variant in variants) {
      final candidates = _markerCandidates(variant.image);
      for (final candidate in candidates.take(3)) {
        final extraction = _extractPadFeatures(
          variant.image,
          featureSpace,
          variant.name,
          candidate,
        );
        if (best == null || extraction.qualityScore > best.qualityScore) {
          best = extraction;
        }
      }
    }

    if (best == null || best.featuresByAnalyte.length < 6) {
      throw StateError(
        'The app could not localize enough dipstick pads offline. Keep the full strip visible, flat, and well lit.',
      );
    }
    return best;
  }

  _FeatureExtraction _extractPadFeatures(
    img.Image image,
    String featureSpace,
    String variantName,
    _MarkerCandidate markerCandidate,
  ) {
    final marker = markerCandidate.rect;
    final markerSize = math.max(marker.width, marker.height).toDouble();
    final pixelsPerMm = markerSize / 20.0;
    final padSize = math.max(6, (5.0 * pixelsPerMm).round());

    final markerPatch = _markerCenterPatch(image, marker);
    final gains = _computeGains(image, markerPatch);
    final grid = _findBestPadGrid(
      image: image,
      marker: marker,
      pixelsPerMm: pixelsPerMm,
      padSize: padSize,
      gains: gains,
    );

    final features = <String, List<double>>{};
    final hues = <double>[];
    final saturationScores = <double>[];
    final values = <double>[];

    for (var i = 0; i < _analyteOrder.length; i++) {
      final baseY = _padY(marker.top, pixelsPerMm, grid.globalYShift, i);
      final refinedY = _refinePadY(
        image: image,
        left: grid.padX,
        baseY: baseY,
        padSize: padSize,
        gains: gains,
        previousExpectedY: i == 0
            ? null
            : _padY(marker.top, pixelsPerMm, grid.globalYShift, i - 1),
        previousFinalY: i == 0 ? null : grid.finalYs[_analyteOrder[i - 1]],
      );
      final roi = _fullRect(
        left: grid.padX,
        top: refinedY,
        width: padSize,
        height: padSize,
        imageWidth: image.width,
        imageHeight: image.height,
      );
      if (roi == null) continue;
      if (roi.width < 4 || roi.height < 4) {
        continue;
      }
      grid.finalYs[_analyteOrder[i]] = refinedY;
      final feature = featureSpace == 'lab'
          ? _meanLab(image, roi, gains)
          : _meanHsv(image, roi, gains);
      features[_analyteOrder[i]] = feature;
      if (featureSpace == 'lab') {
        saturationScores.add(_meanSaturation(image, roi, gains));
      } else {
        hues.add(feature[0]);
        saturationScores.add(feature[1]);
        values.add(feature[2]);
      }
    }

    final hueStd = hues.length < 2 ? 0.0 : _circularHueStd(hues);
    final saturationMean = saturationScores.isEmpty
        ? 0.0
        : saturationScores.reduce((a, b) => a + b) / saturationScores.length;
    final saturationStd = _stdDev(saturationScores);
    final valueStd = _stdDev(values);
    final colorScore = saturationScores.isEmpty ? 0.0 : saturationMean * 18.0;
    final quality =
        markerCandidate.score + grid.score + colorScore + (features.length * 2);
    return _FeatureExtraction(
      variantName: variantName,
      featuresByAnalyte: features,
      qualityScore: quality,
      markerScore: markerCandidate.score,
      markerPatternScore: markerCandidate.patternScore,
      markerFillRatio: markerCandidate.fillRatio,
      markerAspectRatio: markerCandidate.normalizedAspect,
      gridScore: grid.score,
      hueStd: hueStd,
      saturationMean: saturationMean,
      saturationStd: saturationStd,
      valueStd: valueStd,
    );
  }

  List<_MarkerCandidate> _markerCandidates(img.Image image) {
    final scale = math.min(1.0, 900.0 / math.max(image.width, image.height));
    final work = scale < 1.0
        ? img.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
            interpolation: img.Interpolation.nearest,
          )
        : image;

    final visited = List<bool>.filled(work.width * work.height, false);
    final threshold = _darkThreshold(work);
    final candidates = <_MarkerCandidate>[];

    for (var y = 1; y < work.height - 1; y += 2) {
      for (var x = 1; x < work.width - 1; x += 2) {
        final index = y * work.width + x;
        if (visited[index] || !_isDark(work.getPixel(x, y), threshold)) {
          continue;
        }

        final component = _floodDarkComponent(work, x, y, threshold, visited);
        if (component.area < 80) {
          continue;
        }
        final aspect = component.width / math.max(1, component.height);
        final normalizedAspect = aspect < 1 ? 1 / aspect : aspect;
        if (normalizedAspect > 2.8) {
          continue;
        }
        final fill =
            component.area / math.max(1, component.width * component.height);
        if (fill < 0.06 || fill > 0.96) {
          continue;
        }
        if (_touchesBorder(component, work.width, work.height)) {
          continue;
        }

        final pattern = _markerPatternQuality(work, component);
        final score =
            (pattern.score * 8.0) +
            math.min(component.area / (work.width * work.height * 0.04), 1.5);
        final scaled = _Rect(
          left: (component.left / scale).round(),
          top: (component.top / scale).round(),
          width: (component.width / scale).round(),
          height: (component.height / scale).round(),
          area: (component.area / (scale * scale)).round(),
        );
        candidates.add(
          _MarkerCandidate(
            rect: scaled,
            score: score,
            patternScore: pattern.score,
            fillRatio: fill,
            normalizedAspect: normalizedAspect,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  _PadGrid _findBestPadGrid({
    required img.Image image,
    required _Rect marker,
    required double pixelsPerMm,
    required int padSize,
    required List<double> gains,
  }) {
    final expectedX = (marker.left + (32.0 * pixelsPerMm)).round();
    final xSearch = math.max(padSize * 6, marker.width * 0.8).round();
    final ySearch = math.max(padSize * 14, marker.height * 3).round();
    final xStep = math.max(4, padSize ~/ 2);
    final yStep = math.max(4, padSize ~/ 2);

    _PadGrid? best;
    for (var xShift = -xSearch; xShift <= xSearch; xShift += xStep) {
      final x = expectedX + xShift;
      for (var yShift = -ySearch; yShift <= ySearch; yShift += yStep) {
        final score = _gridAlignmentScore(
          image: image,
          padX: x,
          markerTop: marker.top,
          globalYShift: yShift,
          pixelsPerMm: pixelsPerMm,
          padSize: padSize,
          gains: gains,
        );
        if (best == null || score > best.score) {
          best = _PadGrid(
            padX: x,
            globalYShift: yShift,
            score: score,
            finalYs: <String, int>{},
          );
        }
      }
    }

    if (best == null) {
      return _PadGrid(
        padX: expectedX,
        globalYShift: 0,
        score: -1000,
        finalYs: <String, int>{},
      );
    }
    return best;
  }

  double _gridAlignmentScore({
    required img.Image image,
    required int padX,
    required int markerTop,
    required int globalYShift,
    required double pixelsPerMm,
    required int padSize,
    required List<double> gains,
  }) {
    final hues = <double>[];
    final sats = <double>[];
    final vals = <double>[];
    var lockScore = 0.0;
    var validCount = 0;

    for (var i = 0; i < _analyteOrder.length; i++) {
      final rect = _fullRect(
        left: padX,
        top: _padY(markerTop, pixelsPerMm, globalYShift, i),
        width: padSize,
        height: padSize,
        imageWidth: image.width,
        imageHeight: image.height,
      );
      if (rect == null) {
        continue;
      }
      final hsv = _meanHsv(image, rect, gains);
      hues.add(hsv[0]);
      sats.add(hsv[1]);
      vals.add(hsv[2]);
      lockScore += _singlePadLockScore(image, rect, gains);
      validCount++;
    }

    if (validCount < 6) {
      return -10000.0 + validCount;
    }

    final hueStd = _stdDev(hues);
    final satStd = _stdDev(sats);
    final valStd = _stdDev(vals);
    final satMean = sats.reduce((a, b) => a + b) / sats.length;
    return (validCount * 80.0) +
        lockScore +
        hueStd +
        (satStd * 100.0) +
        (valStd * 60.0) +
        (satMean * 25.0);
  }

  int _padY(int markerTop, double pixelsPerMm, int globalYShift, int padIndex) {
    final yMm = 5.0 + (padIndex * 7.5);
    return (markerTop + (yMm * pixelsPerMm)).round() + globalYShift;
  }

  int _refinePadY({
    required img.Image image,
    required int left,
    required int baseY,
    required int padSize,
    required List<double> gains,
    required int? previousExpectedY,
    required int? previousFinalY,
  }) {
    final search = math.max(4, padSize ~/ 2);
    final step = math.max(1, padSize ~/ 8);
    var bestY = baseY;
    var bestScore = -double.infinity;

    for (var dy = -search; dy <= search; dy += step) {
      final y = baseY + dy;
      if (previousExpectedY != null && previousFinalY != null) {
        final expectedStep = baseY - previousExpectedY;
        final actualStep = y - previousFinalY;
        if ((actualStep - expectedStep).abs() > math.max(6, padSize ~/ 2)) {
          continue;
        }
      }
      final rect = _fullRect(
        left: left,
        top: y,
        width: padSize,
        height: padSize,
        imageWidth: image.width,
        imageHeight: image.height,
      );
      if (rect == null) {
        continue;
      }
      final score = _singlePadLockScore(image, rect, gains) - (dy.abs() * 0.05);
      if (score > bestScore) {
        bestScore = score;
        bestY = y;
      }
    }
    return bestY;
  }

  double _singlePadLockScore(img.Image image, _Rect rect, List<double> gains) {
    final hues = <double>[];
    final sats = <double>[];
    final vals = <double>[];
    final step = math.max(2, math.min(rect.width, rect.height) ~/ 8);
    for (var y = rect.top; y < rect.top + rect.height; y += step) {
      for (var x = rect.left; x < rect.left + rect.width; x += step) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        final hsv = _rgbToHsv(rgb[0], rgb[1], rgb[2]);
        hues.add(hsv[0]);
        sats.add(hsv[1]);
        vals.add(hsv[2]);
      }
    }
    if (sats.isEmpty) {
      return -100.0;
    }
    final meanSat = sats.reduce((a, b) => a + b) / sats.length;
    final meanVal = vals.reduce((a, b) => a + b) / vals.length;
    final hueStd = _stdDev(hues);
    final satStd = _stdDev(sats);
    final clipPenalty = meanVal >= 0.995 ? 0.5 : 0.0;
    return (hueStd * 0.1) +
        (meanSat * 25.0) +
        (meanVal * 5.0) -
        (satStd * 20.0) -
        clipPenalty;
  }

  double _stdDev(List<double> values) {
    if (values.length < 2) {
      return 0.0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) {
              final d = value - mean;
              return d * d;
            })
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  double _circularHueStd(List<double> hues) {
    if (hues.length < 2) {
      return 0.0;
    }

    var sinSum = 0.0;
    var cosSum = 0.0;
    for (final hue in hues) {
      final radians = hue * math.pi / 180.0;
      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
    }

    final meanResultantLength =
        math.sqrt((sinSum * sinSum) + (cosSum * cosSum)) / hues.length;
    final safeLength = meanResultantLength.clamp(0.000001, 1.0);
    return math.sqrt(-2.0 * math.log(safeLength)) * 180.0 / math.pi;
  }

  int _darkThreshold(img.Image image) {
    var sum = 0.0;
    var count = 0;
    final step = math.max(1, math.max(image.width, image.height) ~/ 180);
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        sum += _luma(image.getPixel(x, y));
        count++;
      }
    }
    final mean = count == 0 ? 128.0 : sum / count;
    return mean.clamp(70.0, 155.0).round();
  }

  _Rect _floodDarkComponent(
    img.Image image,
    int startX,
    int startY,
    int threshold,
    List<bool> visited,
  ) {
    final queueX = <int>[startX];
    final queueY = <int>[startY];
    var head = 0;
    var minX = startX;
    var maxX = startX;
    var minY = startY;
    var maxY = startY;
    var area = 0;

    visited[startY * image.width + startX] = true;
    while (head < queueX.length) {
      final x = queueX[head];
      final y = queueY[head];
      head++;
      area++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      const neighbors = [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ];
      for (final n in neighbors) {
        final nx = x + n[0];
        final ny = y + n[1];
        if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
          continue;
        }
        final idx = ny * image.width + nx;
        if (visited[idx]) {
          continue;
        }
        visited[idx] = true;
        if (_isDark(image.getPixel(nx, ny), threshold)) {
          queueX.add(nx);
          queueY.add(ny);
        }
      }
    }

    return _Rect(
      left: minX,
      top: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
      area: area,
    );
  }

  bool _isDark(img.Pixel pixel, int threshold) => _luma(pixel) < threshold;

  bool _touchesBorder(_Rect rect, int width, int height) {
    final margin = math.max(2, math.min(width, height) * 0.003);
    return rect.left <= margin ||
        rect.top <= margin ||
        rect.left + rect.width >= width - margin ||
        rect.top + rect.height >= height - margin;
  }

  _MarkerPatternQuality _markerPatternQuality(img.Image image, _Rect rect) {
    final border = <double>[];
    final center = <double>[];
    final x0 = rect.left;
    final y0 = rect.top;
    final x1 = rect.left + rect.width - 1;
    final y1 = rect.top + rect.height - 1;
    final borderBand = math.max(2, math.min(rect.width, rect.height) ~/ 5);

    final step = math.max(1, math.min(rect.width, rect.height) ~/ 28);
    for (var y = y0; y <= y1; y += step) {
      for (var x = x0; x <= x1; x += step) {
        final value =
            _luma(
              image.getPixel(
                x.clamp(0, image.width - 1),
                y.clamp(0, image.height - 1),
              ),
            ) /
            255.0;
        final inBorder =
            x - x0 < borderBand ||
            x1 - x < borderBand ||
            y - y0 < borderBand ||
            y1 - y < borderBand;
        final inCenter =
            x > x0 + rect.width * 0.35 &&
            x < x0 + rect.width * 0.65 &&
            y > y0 + rect.height * 0.35 &&
            y < y0 + rect.height * 0.65;
        if (inBorder) border.add(value);
        if (inCenter) center.add(value);
      }
    }
    if (border.isEmpty || center.isEmpty) {
      return const _MarkerPatternQuality(
        score: 0.0,
        borderMean: 1.0,
        centerMean: 0.0,
        isValid: false,
      );
    }
    final borderMean = border.reduce((a, b) => a + b) / border.length;
    final centerMean = center.reduce((a, b) => a + b) / center.length;
    final contrast = centerMean - borderMean;
    final score = (1.0 - borderMean) + centerMean + (contrast * 2.0);
    final isValid =
        borderMean <= 0.70 &&
        centerMean >= 0.28 &&
        contrast >= 0.10 &&
        score >= 1.10;
    return _MarkerPatternQuality(
      score: score,
      borderMean: borderMean,
      centerMean: centerMean,
      isValid: isValid,
    );
  }

  _Rect _markerCenterPatch(img.Image image, _Rect marker) {
    final size = math.max(4, math.min(marker.width, marker.height) ~/ 8);
    return _clampedRect(
      left: marker.left + marker.width ~/ 2 - size ~/ 2,
      top: marker.top + marker.height ~/ 2 - size ~/ 2,
      width: size,
      height: size,
      imageWidth: image.width,
      imageHeight: image.height,
    );
  }

  List<double> _meanLab(img.Image image, _Rect rect, List<double> gains) {
    var sumL = 0.0;
    var sumA = 0.0;
    var sumB = 0.0;
    var count = 0;

    final step = _colorSampleStep(rect);
    for (var y = rect.top; y < rect.top + rect.height; y += step) {
      for (var x = rect.left; x < rect.left + rect.width; x += step) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        final lab = _rgbToLab(rgb[0], rgb[1], rgb[2]);
        sumL += lab[0];
        sumA += lab[1];
        sumB += lab[2];
        count++;
      }
    }
    return [sumL / count, sumA / count, sumB / count];
  }

  List<double> _meanHsv(img.Image image, _Rect rect, List<double> gains) {
    var sinH = 0.0;
    var cosH = 0.0;
    var sumS = 0.0;
    var sumV = 0.0;
    var count = 0;

    final step = _colorSampleStep(rect);
    for (var y = rect.top; y < rect.top + rect.height; y += step) {
      for (var x = rect.left; x < rect.left + rect.width; x += step) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        final hsv = _rgbToHsv(rgb[0], rgb[1], rgb[2]);
        sinH += math.sin(hsv[0] * math.pi / 180.0);
        cosH += math.cos(hsv[0] * math.pi / 180.0);
        sumS += hsv[1];
        sumV += hsv[2];
        count++;
      }
    }
    final hue = (math.atan2(sinH, cosH) * 180.0 / math.pi) % 360.0;
    return [hue < 0 ? hue + 360.0 : hue, sumS / count, sumV / count];
  }

  double _meanSaturation(img.Image image, _Rect rect, List<double> gains) {
    var sum = 0.0;
    var count = 0;
    final step = math.max(2, _colorSampleStep(rect));
    for (var y = rect.top; y < rect.top + rect.height; y += step) {
      for (var x = rect.left; x < rect.left + rect.width; x += step) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        sum += _rgbToHsv(rgb[0], rgb[1], rgb[2])[1];
        count++;
      }
    }
    return count == 0 ? 0.0 : sum / count;
  }

  List<double> _computeGains(img.Image image, _Rect rect) {
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    var count = 0;
    for (var y = rect.top; y < rect.top + rect.height; y++) {
      for (var x = rect.left; x < rect.left + rect.width; x++) {
        final p = image.getPixel(x, y);
        r += p.r.toDouble();
        g += p.g.toDouble();
        b += p.b.toDouble();
        count++;
      }
    }
    if (count == 0) {
      return [1.0, 1.0, 1.0];
    }
    r = math.max(1.0, r / count);
    g = math.max(1.0, g / count);
    b = math.max(1.0, b / count);
    final target = math.max(r, math.max(g, b));
    return [target / r, target / g, target / b];
  }

  int _colorSampleStep(_Rect rect) =>
      math.max(1, math.min(rect.width, rect.height) ~/ 12);

  List<double> _correctedRgb(img.Pixel pixel, List<double> gains) {
    return [
      (pixel.r.toDouble() * gains[0]).clamp(0.0, 255.0),
      (pixel.g.toDouble() * gains[1]).clamp(0.0, 255.0),
      (pixel.b.toDouble() * gains[2]).clamp(0.0, 255.0),
    ];
  }

  double _luma(img.Pixel pixel) =>
      (0.2126 * pixel.r) + (0.7152 * pixel.g) + (0.0722 * pixel.b);

  _Rect _clampedRect({
    required int left,
    required int top,
    required int width,
    required int height,
    required int imageWidth,
    required int imageHeight,
  }) {
    final x0 = left.clamp(0, imageWidth - 1);
    final y0 = top.clamp(0, imageHeight - 1);
    final x1 = (left + width).clamp(0, imageWidth);
    final y1 = (top + height).clamp(0, imageHeight);
    return _Rect(
      left: x0,
      top: y0,
      width: math.max(0, x1 - x0),
      height: math.max(0, y1 - y0),
      area: math.max(0, x1 - x0) * math.max(0, y1 - y0),
    );
  }

  _Rect? _fullRect({
    required int left,
    required int top,
    required int width,
    required int height,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (left < 0 ||
        top < 0 ||
        left + width > imageWidth ||
        top + height > imageHeight) {
      return null;
    }
    return _Rect(
      left: left,
      top: top,
      width: width,
      height: height,
      area: width * height,
    );
  }
}

Map<String, dynamic> _analyzeScanInBackground(
  String imagePath,
  String referenceText,
) {
  final service = const LocalScanAnalysisService();
  final referenceMap = _ReferenceMap.fromText(referenceText);
  final imageBytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw StateError('Could not decode captured image on device.');
  }

  final baseImage = service._imageForAnalysis(img.bakeOrientation(decoded));
  final extraction = service._extractBestPadFeatures(
    baseImage,
    referenceMap.featureSpace,
  );
  if (!_looksLikeReadableDipstick(extraction)) {
    throw StateError('NO_DIPSTICK_FOUND');
  }

  final rows = <DipstickResultRow>[];
  final confidenceValues = <double>[];

  for (final analyte in _analyteOrder) {
    final observed = extraction.featuresByAnalyte[analyte];
    final prediction = observed == null
        ? null
        : referenceMap.predict(analyte: analyte, observed: observed);
    final level = prediction?.level ?? 'Unavailable';
    final displayLevel = _normalizeDisplayLevel(level);
    final confidence = prediction?.confidence ?? 0.0;
    final code = _codeForAnalyte(analyte);
    confidenceValues.add(confidence);

    rows.add(
      DipstickResultRow(
        code: code,
        name: analyte,
        result: displayLevel,
        referenceRange: _referenceRanges[analyte] ?? 'Reference unavailable',
        status: _isDisplayValueAbnormal(displayLevel)
            ? DipstickResultStatus.moderate
            : DipstickResultStatus.negative,
      ),
    );
  }

  final averageConfidence = confidenceValues.isEmpty
      ? 0.0
      : confidenceValues.reduce((a, b) => a + b) / confidenceValues.length;

  return ScanResult(
    id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
    date: DateTime.now(),
    imagePath: imagePath,
    status: 'complete',
    confidence: averageConfidence,
    posteriorProbability: 0.0,
    riskBucket: 'Complete',
    modelVersion: '${referenceMap.version}_edge',
    rows: rows,
    screeningProbabilities: const <String, double>{},
    padsDetected: extraction.featuresByAnalyte.length,
    padsUnavailable: _analyteOrder.length - extraction.featuresByAnalyte.length,
  ).toJson();
}

bool _looksLikeReadableDipstick(_FeatureExtraction extraction) {
  final hasEnoughPads = extraction.featuresByAnalyte.length >= 6;
  final hasReadableMarker =
      extraction.markerPatternScore >= 0.95 &&
      extraction.markerFillRatio >= 0.06 &&
      extraction.markerFillRatio <= 0.96 &&
      extraction.markerAspectRatio <= 2.8;
  final hasAnyStripSignal =
      extraction.saturationMean >= 0.02 ||
      extraction.saturationStd >= 0.012 ||
      extraction.valueStd >= 0.025 ||
      extraction.hueStd >= 5.0;
  return hasEnoughPads && hasReadableMarker && hasAnyStripSignal;
}

class _ReferenceMap {
  final String version;
  final String featureSpace;
  final int knnK;
  final Map<String, List<_LevelReference>> referencesByAnalyte;

  const _ReferenceMap({
    required this.version,
    required this.featureSpace,
    required this.knnK,
    required this.referencesByAnalyte,
  });

  static _ReferenceMap fromText(String text) {
    final payload = jsonDecode(text) as Map<String, dynamic>;
    final featureSpace = (payload['reference_color_space'] as String? ?? 'hsv')
        .toLowerCase();
    final knnPayload = payload['semiquant_knn'] as Map<String, dynamic>?;
    final knnK = math.max(1, (knnPayload?['k'] as num?)?.round() ?? 31);
    final analytesPayload =
        payload['analytes'] as Map<String, dynamic>? ?? const {};
    final refs = <String, List<_LevelReference>>{};

    for (final analyte in _analyteOrder) {
      final items = analytesPayload[analyte] as List<dynamic>? ?? const [];
      refs[analyte] = items
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final level = item['level'] as String? ?? 'Unavailable';
            if (featureSpace == 'lab') {
              return _LevelReference(
                level: level,
                values: [
                  (item['l'] as num?)?.toDouble() ?? 0.0,
                  (item['a'] as num?)?.toDouble() ?? 0.0,
                  (item['b'] as num?)?.toDouble() ?? 0.0,
                ],
              );
            }
            return _LevelReference(
              level: level,
              values: [
                (item['h'] as num?)?.toDouble() ?? 0.0,
                (item['s'] as num?)?.toDouble() ?? 0.0,
                (item['v'] as num?)?.toDouble() ?? 0.0,
              ],
            );
          })
          .toList(growable: false);
    }

    return _ReferenceMap(
      version: payload['version'] as String? ?? 'edge_reference_map',
      featureSpace: featureSpace,
      knnK: knnK,
      referencesByAnalyte: refs,
    );
  }

  _Prediction? predict({
    required String analyte,
    required List<double> observed,
  }) {
    final refs = referencesByAnalyte[analyte] ?? const [];
    if (refs.isEmpty) {
      return null;
    }

    final distances =
        refs
            .map(
              (ref) =>
                  MapEntry(ref, _distance(observed, ref.values, featureSpace)),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    final neighbors = distances.take(math.min(knnK, distances.length));
    final votes = <String, double>{};
    for (final item in neighbors) {
      votes[item.key.level] =
          (votes[item.key.level] ?? 0.0) + (1.0 / (item.value + 1e-9));
    }
    final rankedVotes = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final bestVote = rankedVotes.first;
    final voteTotal = rankedVotes.fold<double>(
      0.0,
      (total, item) => total + item.value,
    );
    final confidence = voteTotal <= 0.0 ? 0.0 : bestVote.value / voteTotal;
    final second = rankedVotes.length > 1 && voteTotal > 0.0
        ? rankedVotes[1].value / voteTotal
        : 0.0;
    final best = distances.firstWhere(
      (item) => item.key.level == bestVote.key,
      orElse: () => distances.first,
    );
    return _Prediction(
      level: bestVote.key,
      confidence: confidence,
      distance: best.value,
      margin: confidence - second,
    );
  }

  double _distance(List<double> a, List<double> b, String featureSpace) {
    if (featureSpace == 'hsv' || featureSpace == 'normalized_hsv') {
      final hueDelta =
          math.min((a[0] - b[0]).abs(), 360.0 - (a[0] - b[0]).abs()) / 180.0;
      final ds = a[1] - b[1];
      final dv = a[2] - b[2];
      return math.sqrt((hueDelta * hueDelta) + (ds * ds) + (dv * dv));
    }
    final d0 = a[0] - b[0];
    final d1 = a[1] - b[1];
    final d2 = a[2] - b[2];
    return math.sqrt((d0 * d0) + (d1 * d1) + (d2 * d2));
  }
}

class _ImageVariant {
  final String name;
  final img.Image image;

  const _ImageVariant(this.name, this.image);
}

class _FeatureExtraction {
  final String variantName;
  final Map<String, List<double>> featuresByAnalyte;
  final double qualityScore;
  final double markerScore;
  final double markerPatternScore;
  final double markerFillRatio;
  final double markerAspectRatio;
  final double gridScore;
  final double hueStd;
  final double saturationMean;
  final double saturationStd;
  final double valueStd;

  const _FeatureExtraction({
    required this.variantName,
    required this.featuresByAnalyte,
    required this.qualityScore,
    required this.markerScore,
    required this.markerPatternScore,
    required this.markerFillRatio,
    required this.markerAspectRatio,
    required this.gridScore,
    required this.hueStd,
    required this.saturationMean,
    required this.saturationStd,
    required this.valueStd,
  });
}

class _MarkerCandidate {
  final _Rect rect;
  final double score;
  final double patternScore;
  final double fillRatio;
  final double normalizedAspect;

  const _MarkerCandidate({
    required this.rect,
    required this.score,
    required this.patternScore,
    required this.fillRatio,
    required this.normalizedAspect,
  });
}

class _MarkerPatternQuality {
  final double score;
  final double borderMean;
  final double centerMean;
  final bool isValid;

  const _MarkerPatternQuality({
    required this.score,
    required this.borderMean,
    required this.centerMean,
    required this.isValid,
  });
}

class _PadGrid {
  final int padX;
  final int globalYShift;
  final double score;
  final Map<String, int> finalYs;

  const _PadGrid({
    required this.padX,
    required this.globalYShift,
    required this.score,
    required this.finalYs,
  });
}

class _LevelReference {
  final String level;
  final List<double> values;

  const _LevelReference({required this.level, required this.values});
}

class _Prediction {
  final String level;
  final double confidence;
  final double distance;
  final double margin;

  const _Prediction({
    required this.level,
    required this.confidence,
    required this.distance,
    required this.margin,
  });
}

class _Rect {
  final int left;
  final int top;
  final int width;
  final int height;
  final int area;

  const _Rect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.area,
  });
}

String _codeForAnalyte(String analyte) {
  switch (analyte) {
    case 'Leukocytes':
      return 'LEU';
    case 'Nitrite':
      return 'NIT';
    case 'Urobilinogen':
      return 'URO';
    case 'Protein':
      return 'PRO';
    case 'pH':
      return 'pH';
    case 'Blood':
      return 'BLD';
    case 'Specific Gravity':
      return 'SG';
    case 'Ketone':
      return 'KET';
    case 'Bilirubin':
      return 'BIL';
    case 'Glucose':
      return 'GLU';
    default:
      return analyte.toUpperCase();
  }
}

String _normalizeDisplayLevel(String level) {
  final normalized = level.trim();
  if (normalized.toLowerCase() == 'neg') {
    return 'Negative';
  }
  return normalized.isEmpty ? 'Unavailable' : normalized;
}

bool _isDisplayValueAbnormal(String level) {
  final normalized = level.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'unavailable') {
    return false;
  }
  return normalized != 'neg' && normalized != 'negative';
}

List<double> _rgbToHsv(double r, double g, double b) {
  final rn = r / 255.0;
  final gn = g / 255.0;
  final bn = b / 255.0;
  final maxValue = math.max(rn, math.max(gn, bn));
  final minValue = math.min(rn, math.min(gn, bn));
  final delta = maxValue - minValue;

  var hue = 0.0;
  if (delta != 0) {
    if (maxValue == rn) {
      hue = 60.0 * (((gn - bn) / delta) % 6.0);
    } else if (maxValue == gn) {
      hue = 60.0 * (((bn - rn) / delta) + 2.0);
    } else {
      hue = 60.0 * (((rn - gn) / delta) + 4.0);
    }
  }
  if (hue < 0) hue += 360.0;
  final saturation = maxValue == 0 ? 0.0 : delta / maxValue;
  return [hue, saturation, maxValue];
}

List<double> _rgbToLab(double r, double g, double b) {
  double pivotRgb(double value) {
    final normalized = value / 255.0;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  final rr = pivotRgb(r);
  final gg = pivotRgb(g);
  final bb = pivotRgb(b);

  final x = ((rr * 0.4124564) + (gg * 0.3575761) + (bb * 0.1804375)) / 0.95047;
  final y = (rr * 0.2126729) + (gg * 0.7151522) + (bb * 0.0721750);
  final z = ((rr * 0.0193339) + (gg * 0.1191920) + (bb * 0.9503041)) / 1.08883;

  double pivotXyz(double value) {
    return value > 0.008856
        ? math.pow(value, 1.0 / 3.0).toDouble()
        : (7.787 * value) + (16.0 / 116.0);
  }

  final fx = pivotXyz(x);
  final fy = pivotXyz(y);
  final fz = pivotXyz(z);
  return [(116.0 * fy) - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)];
}
