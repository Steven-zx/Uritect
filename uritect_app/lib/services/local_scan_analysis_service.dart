import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/dipstick_results_data.dart';
import '../models/scan_model.dart';
import '../models/scan_localization.dart';
import '../models/scan_analysis_failure.dart';
import 'training_support_policy.dart';

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
    void Function(ScanLocalization localization)? onLocalization,
  }) async {
    onProgress?.call(5, 'loading_production_model');
    final modelText = await rootBundle.loadString(
      'assets/production_semiquant_model.json',
    );
    final policyText = await rootBundle.loadString(
      'assets/training_support_policy.json',
    );

    onProgress?.call(18, 'preparing_image');
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image was not found on this device.');
    }

    onProgress?.call(32, 'locating_markerless_strip');
    final events = ReceivePort();
    final sendPort = onLocalization == null ? null : events.sendPort;
    final eventsDone = Completer<void>();
    final subscription = events.listen((message) {
      if ((message as Map)['done'] == true) {
        eventsDone.complete();
        return;
      }
      final localization = ScanLocalization.fromMessage(message);
      onLocalization?.call(localization);
      if (localization.regions.isNotEmpty) {
        onProgress?.call(80, 'classifying_pads');
      }
    });
    late Map<String, dynamic> resultJson;
    try {
      final request = _AnalysisRequest(
        imagePath,
        modelText,
        policyText,
        sendPort,
      );
      resultJson = await Isolate.run(request.run);
    } finally {
      // Drain detector messages before returning or propagating rejection.
      if (sendPort != null) await eventsDone.future;
      await subscription.cancel();
      events.close();
    }

    onProgress?.call(92, 'finalizing_results');
    final scanResult = ScanResult.fromJson(resultJson);
    onProgress?.call(100, 'complete');
    return scanResult;
  }

  img.Image _imageForAnalysis(img.Image image) {
    const maxSide = 1100;
    final currentMaxSide = math.max(image.width, image.height);
    if (currentMaxSide <= maxSide) return image;
    final scale = maxSide / currentMaxSide;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  _FeatureExtraction _extractBestPadFeatures(img.Image image) {
    final variants = <_ImageVariant>[
      _ImageVariant('exif', image),
      _ImageVariant('rot90_cw', img.copyRotate(image, angle: 90)),
      _ImageVariant('rot180', img.copyRotate(image, angle: 180)),
      _ImageVariant('rot90_ccw', img.copyRotate(image, angle: -90)),
    ];

    // Do not let a detector that selects one strip override a clear second
    // narrow bright strip. Checking the two axes covers both capture rotations.
    for (final variant in variants.take(2)) {
      try {
        _detectStripBoxLocalContrast(variant.image);
      } on StateError catch (error) {
        if (error.message.toString().contains(
          'Multiple local-contrast strip candidates',
        )) {
          rethrow;
        }
      }
    }

    final errors = <String>[];
    ScanAnalysisFailure? padBoundaryFailure;
    // Preserve established geometry on captures the existing detector reads.
    // Use background-relative detection only when no legacy orientation passes
    // the full geometry checks. Confidence never selects a detector or bypasses
    // the abstention policy.
    for (final detector in [
      'legacy',
      'background_relative',
      'local_contrast',
      'legacy_backing',
      'background_relative_backing',
      'local_contrast_backing',
    ]) {
      _FeatureExtraction? best;
      for (final variant in variants) {
        try {
          final extraction = _extractMarkerlessFeatures(
            variant.image,
            variant.name + (detector == 'legacy' ? '' : '_$detector'),
            relativeBackground: detector.startsWith('background_relative'),
            localContrast: detector.startsWith('local_contrast'),
            backingContrast: detector.endsWith('_backing'),
          );
          _validateReadableCapture(extraction);
          if (best == null || extraction.qualityScore > best.qualityScore) {
            best = extraction;
          }
        } catch (error) {
          if (error is ScanAnalysisFailure) padBoundaryFailure ??= error;
          errors.add('${variant.name}_$detector: $error');
        }
      }
      if (best != null) return best;
    }
    if (padBoundaryFailure != null) throw padBoundaryFailure;
    throw StateError(
      'INVALID_IMAGE: Could not locate a complete ten-pad strip. ${[errors.first, errors.last].join('; ')}',
    );
  }

  _FeatureExtraction _extractMarkerlessFeatures(
    img.Image image,
    String orientation, {
    bool relativeBackground = false,
    bool localContrast = false,
    bool backingContrast = false,
  }) {
    _rejectBlankOrBlurred(image);
    var strip = localContrast
        ? _detectStripBoxLocalContrast(image)
        : relativeBackground
        ? _detectStripBoxRelative(image)
        : _detectStripBoxLegacy(image);
    final gains = _grayWorldGains(image, strip);
    final padSize = math.max(8, (strip.width * 0.58).round());
    final initialDetectedCropX =
        (localContrast || backingContrast
            ? null
            : _detectGlobalPadColumn(image, padSize, gains)) ??
        (strip.left + strip.width / 2.0 - padSize / 2.0).round();
    final initialCropX = initialDetectedCropX
        .clamp(0, math.max(0, image.width - padSize))
        .toInt();
    final padColumn = _StripRect(
      left: initialCropX,
      top: strip.top,
      width: padSize,
      height: strip.height,
      area: padSize * strip.height,
      quality: strip.quality,
    );
    final centers = backingContrast
        ? _detectPadCentersAgainstBacking(image, padColumn, padSize)
        : _detectPadCenters(image, padColumn, padSize, gains);
    if (centers.length != _analyteOrder.length) {
      throw StateError('INVALID_IMAGE: Expected ten reagent pads.');
    }
    if (backingContrast) {
      // Extend to measured pale endpoint pads, never extrapolated pad positions.
      final top = math.min(strip.top, (centers.first - padSize / 2).floor());
      final bottom = math.max(
        strip.top + strip.height,
        (centers.last + padSize / 2).ceil(),
      );
      strip = _StripRect(
        left: strip.left,
        top: top,
        width: strip.width,
        height: bottom - top,
        area: strip.width * (bottom - top),
        quality: strip.quality,
      );
    }
    final refinedCropX =
        (localContrast || backingContrast
            ? null
            : _detectPadColumn(image, centers, padSize, padColumn, gains)) ??
        initialCropX;
    final cropX = refinedCropX
        .clamp(0, math.max(0, image.width - padSize))
        .toInt();

    final raw = <String, List<double>>{};
    final rois = <String, _Rect>{};
    final sats = <double>[];
    final vals = <double>[];
    final hues = <double>[];
    for (var i = 0; i < _analyteOrder.length; i++) {
      final analyte = _analyteOrder[i];
      final cropY = (centers[i] - padSize / 2.0)
          .round()
          .clamp(0, math.max(0, image.height - padSize))
          .toInt();
      final roi = _Rect(
        left: cropX,
        top: cropY,
        width: padSize,
        height: padSize,
        area: padSize * padSize,
      );
      final hsv = _meanHsv(image, roi, gains);
      raw[analyte] = hsv;
      rois[analyte] = roi;
      hues.add(hsv[0]);
      sats.add(hsv[1]);
      vals.add(hsv[2]);
    }

    final normalized = _normalizeHsvFeatures(raw);
    final gaps = <double>[];
    for (var i = 1; i < centers.length; i++) {
      gaps.add(centers[i] - centers[i - 1]);
    }
    final medianGap = _median(gaps);
    final gapCv = medianGap <= 0 ? 999.0 : _stdDev(gaps) / medianGap;
    final satMean = _mean(sats);
    final satStd = _stdDev(sats);
    final valStd = _stdDev(vals);
    final hueStd = _circularHueStd(hues);
    final quality =
        strip.quality +
        (10.0 * (1.0 - gapCv).clamp(0.0, 1.0)) +
        (satMean * 18.0) +
        (satStd * 10.0) +
        (valStd * 6.0);

    return _FeatureExtraction(
      variantName: orientation,
      featuresByAnalyte: normalized,
      rawFeaturesByAnalyte: raw,
      padRois: rois,
      stripRect: strip,
      imageWidth: image.width,
      imageHeight: image.height,
      qualityScore: quality,
      padGapCv: gapCv,
      hueStd: hueStd,
      saturationMean: satMean,
      saturationStd: satStd,
      valueStd: valStd,
    );
  }

  void _rejectBlankOrBlurred(img.Image image) {
    final step = math.max(2, math.max(image.width, image.height) ~/ 180);
    final lumas = <double>[];
    final sats = <double>[];
    var lapSum = 0.0;
    var lapCount = 0;
    for (var y = step; y < image.height - step; y += step) {
      for (var x = step; x < image.width - step; x += step) {
        final p = image.getPixel(x, y);
        final l = _luma(p);
        lumas.add(l);
        sats.add(_rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble())[1]);
        final c = l * 4.0;
        final n = _luma(image.getPixel(x, y - step));
        final s = _luma(image.getPixel(x, y + step));
        final e = _luma(image.getPixel(x + step, y));
        final w = _luma(image.getPixel(x - step, y));
        lapSum += (c - n - s - e - w).abs();
        lapCount++;
      }
    }
    if (lumas.isEmpty) throw StateError('INVALID_IMAGE: Image is unreadable.');
    final lumaStd = _stdDev(lumas);
    final lumaMean = _mean(lumas);
    final satMean = _mean(sats);
    final blurScore = lapCount == 0 ? 0.0 : lapSum / lapCount;
    if (lumaMean < 28.0) {
      throw StateError('INVALID_IMAGE: Image is too dark for pad reading.');
    }
    if (lumaMean > 242.0 && lumaStd < 18.0) {
      throw StateError('INVALID_IMAGE: Image is overexposed for pad reading.');
    }
    if (lumaStd < 6.0 && satMean < 0.035) {
      throw StateError(
        'INVALID_IMAGE: Blank image or no visible strip signal.',
      );
    }
    if (blurScore < 2.8) {
      throw StateError('INVALID_IMAGE: Image is too blurred for pad reading.');
    }
  }

  // Compare with the background on the same row, interpolating the side
  // margins to account for a lighting gradient. Absolute saturation treats a
  // blue/orange-lit background as one enormous strip and rejects real strips.
  List<List<double>> _rowBackground(img.Image image) {
    final margin = math.max(2, (image.width * .04).round());
    return [
      for (var y = 0; y < image.height; y++)
        [
          for (final side in [0, 1]) ...[
            for (var channel = 0; channel < 3; channel++)
              _median([
                for (var i = 0; i < margin; i += math.max(1, margin ~/ 8))
                  _pixelChannel(
                    image.getPixel(side == 0 ? i : image.width - 1 - i, y),
                    channel,
                  ),
              ]),
          ],
        ],
    ];
  }

  double _pixelChannel(img.Pixel pixel, int channel) => channel == 0
      ? pixel.r.toDouble()
      : channel == 1
      ? pixel.g.toDouble()
      : pixel.b.toDouble();

  bool _differsFromBackground(
    img.Pixel pixel,
    int x,
    int width,
    List<double> row,
  ) {
    final fraction = x / math.max(1, width - 1);
    var sum = 0.0;
    for (var channel = 0; channel < 3; channel++) {
      final expected =
          row[channel] * (1 - fraction) + row[channel + 3] * fraction;
      final delta = (_pixelChannel(pixel, channel) - expected) / 255.0;
      sum += delta * delta;
    }
    return math.sqrt(sum) > .08;
  }

  _StripRect _detectStripBoxLegacy(img.Image image) {
    final colScores = List<double>.filled(image.width, 0.0);
    final rowStep = math.max(1, image.height ~/ 500);
    for (var x = 0; x < image.width; x++) {
      var active = 0;
      var total = 0;
      for (var y = 0; y < image.height; y += rowStep) {
        final p = image.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (hsv[1] > 0.16 && hsv[2] > 0.10 && hsv[2] < 0.985) active++;
        total++;
      }
      colScores[x] = total == 0 ? 0.0 : active / total;
    }
    final smoothedCols = _smooth(colScores, math.max(9, image.width ~/ 100));
    final threshold = math.max(0.035, _percentile(smoothedCols, 95) * 0.40);
    final runs = _runs(smoothedCols.map((v) => v >= threshold).toList());
    if (runs.isEmpty) {
      throw StateError('INVALID_IMAGE: No vertical strip candidate.');
    }

    _Run? best;
    double bestScore = -1;
    final plausibleScores = <double>[];
    for (final run in runs) {
      final width = run.end - run.start + 1;
      if (width < 14 || width > image.width * 0.24) continue;
      final score = _mean(smoothedCols.sublist(run.start, run.end + 1));
      plausibleScores.add(score);
      if (score > bestScore) {
        best = run;
        bestScore = score;
      }
    }
    if (best == null) {
      throw StateError('INVALID_IMAGE: Strip candidate is not plausible.');
    }
    final strongRunCount = plausibleScores
        .where((score) => score >= math.max(0.03, bestScore * 0.72))
        .length;
    if (strongRunCount > 1) {
      throw StateError(
        'INVALID_IMAGE: Multiple plausible strips or strip-like objects were found.',
      );
    }

    var x0 = best.start;
    var x1 = best.end;
    final xPad = ((x1 - x0 + 1) * 0.18).round();
    x0 = math.max(0, x0 - xPad);
    x1 = math.min(image.width - 1, x1 + xPad);
    final stripWidth = x1 - x0 + 1;

    final rowScores = List<double>.filled(image.height, 0.0);
    final colStep = math.max(1, stripWidth ~/ 40);
    for (var y = 0; y < image.height; y++) {
      var active = 0;
      var total = 0;
      for (var x = x0; x <= x1; x += colStep) {
        final p = image.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (hsv[1] > 0.12 && hsv[2] > 0.10 && hsv[2] < 0.985) active++;
        total++;
      }
      rowScores[y] = total == 0 ? 0.0 : active / total;
    }
    final smoothedRows = _smooth(rowScores, math.max(17, image.height ~/ 120));
    final rowThreshold = math.max(0.025, _percentile(smoothedRows, 82) * 0.35);
    final activeRows = <int>[];
    for (var i = 0; i < smoothedRows.length; i++) {
      if (smoothedRows[i] >= rowThreshold) activeRows.add(i);
    }
    if (activeRows.isEmpty) {
      throw StateError('INVALID_IMAGE: No reagent-pad row signal.');
    }
    final y0 = activeRows.first;
    final y1 = activeRows.last;
    final stripHeight = y1 - y0 + 1;
    if (stripHeight / math.max(1, stripWidth) < 3.0) {
      throw StateError('INVALID_IMAGE: Partial or wrong strip geometry.');
    }
    if (stripWidth / image.width > 0.24) {
      throw StateError('INVALID_IMAGE: Strip candidate is too wide.');
    }
    return _StripRect(
      left: x0,
      top: y0,
      width: stripWidth,
      height: stripHeight,
      area: stripWidth * stripHeight,
      quality: 2.0 + bestScore + stripHeight / image.height,
    );
  }

  _StripRect _detectStripBoxRelative(img.Image image) {
    final background = _rowBackground(image);
    final colScores = List<double>.filled(image.width, 0.0);
    final rowStep = math.max(1, image.height ~/ 500);
    for (var x = 0; x < image.width; x++) {
      var active = 0;
      var total = 0;
      for (var y = 0; y < image.height; y += rowStep) {
        final p = image.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (_differsFromBackground(p, x, image.width, background[y]) &&
            hsv[2] > 0.10 &&
            hsv[2] < 0.995) {
          active++;
        }
        total++;
      }
      colScores[x] = total == 0 ? 0.0 : active / total;
    }
    final smoothedCols = _smooth(colScores, math.max(9, image.width ~/ 100));
    final threshold = math.max(0.035, _percentile(smoothedCols, 95) * 0.40);
    final runs = _runs(smoothedCols.map((v) => v >= threshold).toList());
    if (runs.isEmpty) {
      throw StateError('INVALID_IMAGE: No vertical strip candidate.');
    }

    _Run? best;
    double bestScore = -1;
    final plausibleScores = <double>[];
    for (final run in runs) {
      final width = run.end - run.start + 1;
      if (width < 14 || width > image.width * 0.24) continue;
      final score = _mean(smoothedCols.sublist(run.start, run.end + 1));
      plausibleScores.add(score);
      if (score > bestScore) {
        best = run;
        bestScore = score;
      }
    }
    if (best == null) {
      throw StateError('INVALID_IMAGE: Strip candidate is not plausible.');
    }
    final strongRunCount = plausibleScores
        .where((score) => score >= math.max(0.03, bestScore * 0.72))
        .length;
    if (strongRunCount > 1) {
      throw StateError(
        'INVALID_IMAGE: Multiple plausible strips or strip-like objects were found.',
      );
    }

    var x0 = best.start;
    var x1 = best.end;
    final xPad = ((x1 - x0 + 1) * 0.18).round();
    x0 = math.max(0, x0 - xPad);
    x1 = math.min(image.width - 1, x1 + xPad);
    final stripWidth = x1 - x0 + 1;

    final rowScores = List<double>.filled(image.height, 0.0);
    final colStep = math.max(1, stripWidth ~/ 40);
    for (var y = 0; y < image.height; y++) {
      var active = 0;
      var total = 0;
      for (var x = x0; x <= x1; x += colStep) {
        final p = image.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (_differsFromBackground(p, x, image.width, background[y]) &&
            hsv[2] > 0.10 &&
            hsv[2] < 0.995) {
          active++;
        }
        total++;
      }
      rowScores[y] = total == 0 ? 0.0 : active / total;
    }
    final smoothedRows = _smooth(rowScores, math.max(17, image.height ~/ 120));
    final rowThreshold = math.max(0.025, _percentile(smoothedRows, 82) * 0.35);
    final activeRows = <int>[];
    for (var i = 0; i < smoothedRows.length; i++) {
      if (smoothedRows[i] >= rowThreshold) activeRows.add(i);
    }
    if (activeRows.isEmpty) {
      throw StateError('INVALID_IMAGE: No reagent-pad row signal.');
    }
    final y0 = activeRows.first;
    final y1 = activeRows.last;
    final stripHeight = y1 - y0 + 1;
    if (stripHeight / math.max(1, stripWidth) < 3.0) {
      throw StateError('INVALID_IMAGE: Partial or wrong strip geometry.');
    }
    if (stripWidth / image.width > 0.24) {
      throw StateError('INVALID_IMAGE: Strip candidate is too wide.');
    }
    return _StripRect(
      left: x0,
      top: y0,
      width: stripWidth,
      height: stripHeight,
      area: stripWidth * stripHeight,
      quality: 2.0 + bestScore + stripHeight / image.height,
    );
  }

  // Textured floors defeat both absolute saturation and image-edge background
  // estimates. Compare a narrow bright strip with its immediate surroundings.
  // This is only attempted after both established detectors fail validation.
  _StripRect _detectStripBoxLocalContrast(img.Image image) {
    final offset = math.max(12, (image.width * .055).round());
    bool brightAgainstBothSides(int x, int y) {
      final center = _luma(image.getPixel(x, y));
      return center - _luma(image.getPixel(x - offset, y)) > 20 &&
          center - _luma(image.getPixel(x + offset, y)) > 20;
    }

    final scores = List<double>.filled(image.width, 0);
    final rowStep = math.max(1, image.height ~/ 500);
    for (var x = offset; x < image.width - offset; x++) {
      var active = 0;
      var total = 0;
      for (var y = 0; y < image.height; y += rowStep) {
        if (brightAgainstBothSides(x, y)) active++;
        total++;
      }
      scores[x] = active / math.max(1, total);
    }
    final smooth = _smooth(scores, math.max(9, image.width ~/ 100));
    final threshold = math.max(.20, _percentile(smooth, 95) * .55);
    final runs = _runs(
      smooth.map((v) => v > threshold).toList(),
    ).where((r) => r.length >= 14 && r.length <= image.width * .16).toList();
    if (runs.isEmpty) {
      throw StateError(
        'INVALID_IMAGE: No narrow local-contrast strip candidate.',
      );
    }
    runs.sort(
      (a, b) => _mean(
        smooth.sublist(b.start, b.end + 1),
      ).compareTo(_mean(smooth.sublist(a.start, a.end + 1))),
    );
    final best = runs.first;
    final strength = _mean(smooth.sublist(best.start, best.end + 1));
    if (runs
        .skip(1)
        .any(
          (r) => _mean(smooth.sublist(r.start, r.end + 1)) >= strength * .72,
        )) {
      throw StateError(
        'INVALID_IMAGE: Multiple local-contrast strip candidates.',
      );
    }
    final center = (best.start + best.end) ~/ 2;
    final activeRows = <int>[
      for (var y = 0; y < image.height; y++)
        if (brightAgainstBothSides(center, y)) y,
    ];
    if (activeRows.isEmpty) {
      throw StateError('INVALID_IMAGE: No local-contrast strip extent.');
    }
    final padding = (best.length * .18).round();
    final left = math.max(0, best.start - padding);
    final right = math.min(image.width - 1, best.end + padding);
    final top = activeRows.first;
    final height = activeRows.last - top + 1;
    final width = right - left + 1;
    if (height / width < 3 || height < image.height * .35) {
      throw StateError('INVALID_IMAGE: Partial local-contrast strip geometry.');
    }
    return _StripRect(
      left: left,
      top: top,
      width: width,
      height: height,
      area: width * height,
      quality: 2 + strength + height / image.height,
    );
  }

  List<double> _detectPadCentersAgainstBacking(
    img.Image image,
    _StripRect column,
    int padSize,
  ) {
    final colors = <List<double>>[];
    final x0 = column.left.clamp(0, image.width - 1);
    final x1 = (column.left + column.width - 1).clamp(0, image.width - 1);
    for (var y = 0; y < image.height; y++) {
      final sums = [0.0, 0.0, 0.0];
      var count = 0;
      for (var x = x0; x <= x1; x += math.max(1, padSize ~/ 20)) {
        final p = image.getPixel(x, y);
        sums[0] += p.r;
        sums[1] += p.g;
        sums[2] += p.b;
        count++;
      }
      colors.add(sums.map((v) => v / math.max(1, count)).toList());
    }
    // Compare with nearby bright plastic. Ratios suppress illumination changes;
    // ten measured color regions are required, with no grid-based pad filling.
    final radius = math.max(20, (padSize * 2.1).round());
    final score = List<double>.filled(image.height, 0);
    for (var y = 0; y < image.height; y++) {
      final window = colors.sublist(
        math.max(0, y - radius),
        math.min(image.height, y + radius + 1),
      );
      final brightBlue = _percentile(window.map((c) => c[2]).toList(), 90);
      final reference = window.where((c) => c[2] >= brightBlue).toList();
      final r = _mean(reference.map((c) => c[0]).toList());
      final g = _mean(reference.map((c) => c[1]).toList());
      final b = math.max(20.0, _mean(reference.map((c) => c[2]).toList()));
      final pixelBlue = math.max(20.0, colors[y][2]);
      final dr = colors[y][0] / pixelBlue - r / b;
      final dg = colors[y][1] / pixelBlue - g / b;
      score[y] = math.sqrt(dr * dr + dg * dg);
    }
    final smoothed = _smooth(score, math.max(9, padSize ~/ 4));
    var runs = _runs(
      smoothed.map((v) => v > .020).toList(),
    ).where((r) => r.length >= math.max(10, (padSize * .35).round())).toList();
    if (runs.length > 10) runs = _bestConsecutiveRuns(runs, smoothed, 10);
    if (runs.length != 10 ||
        runs.first.start < 3 ||
        runs.last.end > image.height - 4) {
      throw ScanAnalysisFailure(
        code: 'PAD_BOUNDARIES_UNCLEAR',
        guidance:
            'Ten separate reagent pads could not be confirmed. Keep every pad visible, reduce glare, and tap to focus before retaking.',
      );
    }
    final offset = math.max(padSize + 8, (padSize * 1.5).round());
    final centerX = (x0 + x1) ~/ 2;
    double shaftContrast(int start, int end) {
      final a = start.clamp(0, image.height);
      final b = end.clamp(0, image.height);
      if (b - a < padSize ||
          centerX < offset ||
          centerX + offset >= image.width) {
        return 0;
      }
      final values = <double>[];
      for (var y = a; y < b; y++) {
        final center = colors[y];
        final left = image.getPixel(centerX - offset, y);
        final right = image.getPixel(centerX + offset, y);
        double distance(img.Pixel p) => math.sqrt(
          math.pow(center[0] - p.r, 2) +
              math.pow(center[1] - p.g, 2) +
              math.pow(center[2] - p.b, 2),
        );
        values.add(math.min(distance(left), distance(right)));
      }
      return _mean(values);
    }

    final before = shaftContrast(
      runs.first.start - padSize * 3,
      runs.first.start - 4,
    );
    final after = shaftContrast(runs.last.end + 4, runs.last.end + padSize * 3);
    if (after < 8 || after <= before * 1.4) {
      throw ScanAnalysisFailure(
        code: 'STRIP_DIRECTION_UNCLEAR',
        guidance:
            'The strip direction could not be confirmed. Include the plain handle below the last pad and keep all ten pads visible.',
      );
    }
    return runs.map((r) => (r.start + r.end) / 2).toList();
  }

  List<double> _detectPadCenters(
    img.Image image,
    _StripRect strip,
    int padSize,
    List<double> gains,
  ) {
    final centerX = strip.left + strip.width ~/ 2;
    final halfWidth = math.max(4, (strip.width * 0.42).round());
    final x0 = math.max(0, centerX - halfWidth);
    final x1 = math.min(image.width - 1, centerX + halfWidth);
    final rowScore = List<double>.filled(image.height, 0.0);

    for (var y = 0; y < image.height; y++) {
      final samples = <double>[];
      final step = math.max(1, (x1 - x0 + 1) ~/ 32);
      for (var x = x0; x <= x1; x += step) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        final hsv = _rgbToHsv(rgb[0], rgb[1], rgb[2]);
        final chroma = _rgbChroma(rgb[0], rgb[1], rgb[2]);
        final valueScore = 1.0 - (hsv[2] - 0.55).abs();
        samples.add(
          (0.52 * hsv[1]) +
              (0.34 * chroma) +
              (0.14 * valueScore.clamp(0.0, 1.0)),
        );
      }
      rowScore[y] = samples.isEmpty ? 0.0 : _mean(samples);
    }

    final smoothed = _smooth(rowScore, math.max(11, padSize ~/ 4));
    final threshold = math.max(0.10, _percentile(smoothed, 70) * 0.50);
    var runs = _runs(smoothed.map((v) => v >= threshold).toList())
        .where((run) => run.length >= math.max(10, (padSize * 0.20).round()))
        .toList();
    if (runs.length > _analyteOrder.length) {
      runs = _bestConsecutiveRuns(runs, smoothed, _analyteOrder.length);
    }
    if (runs.length != _analyteOrder.length) {
      throw ScanAnalysisFailure(
        code: 'PAD_BOUNDARIES_UNCLEAR',
        guidance:
            'A strip-like region was found, but ten separate reagent pads could not be confirmed. Lay the strip flat on a plain background, reduce glare, tap to focus, and retake the photo.',
      );
    }
    return runs.map((run) => (run.start + run.end) / 2.0).toList();
  }

  int? _detectGlobalPadColumn(
    img.Image image,
    int padSize,
    List<double> gains,
  ) {
    final colScores = List<double>.filled(image.width, 0.0);
    final rowStep = math.max(1, image.height ~/ 900);
    for (var x = 0; x < image.width; x++) {
      final samples = <double>[];
      for (var y = 0; y < image.height; y += rowStep) {
        final rgb = _correctedRgb(image.getPixel(x, y), gains);
        final hsv = _rgbToHsv(rgb[0], rgb[1], rgb[2]);
        final activity = hsv[1] > 0.12 && hsv[2] > 0.10 && hsv[2] < 0.985
            ? 1.0
            : 0.0;
        samples.add(activity);
      }
      colScores[x] = samples.isEmpty ? 0.0 : _mean(samples);
    }

    final smoothed = _smooth(colScores, math.max(7, padSize ~/ 8));
    final threshold = math.max(0.04, _percentile(smoothed, 95) * 0.45);
    final runs = _runs(smoothed.map((v) => v >= threshold).toList())
        .where(
          (run) =>
              run.length >= math.max(12, (padSize * 0.45).round()) &&
              run.length <= math.max(13, (padSize * 2.4).round()),
        )
        .toList();
    if (runs.isEmpty) {
      return null;
    }

    _Run? best;
    var bestScore = -double.infinity;
    for (final run in runs) {
      final score = _mean(smoothed.sublist(run.start, run.end + 1));
      if (score > bestScore) {
        bestScore = score;
        best = run;
      }
    }
    if (best == null) {
      return null;
    }
    return (((best.start + best.end) / 2.0) - padSize / 2.0).round();
  }

  int? _detectPadColumn(
    img.Image image,
    List<double> centers,
    int padSize,
    _StripRect strip,
    List<double> gains,
  ) {
    final colScores = List<double>.filled(image.width, 0.0);
    final bandHalf = math.max(4, (padSize * 0.38).round());
    final selectedRows = <int>{};
    for (final center in centers) {
      final cy = center.round();
      for (
        var y = math.max(0, cy - bandHalf);
        y <= math.min(image.height - 1, cy + bandHalf);
        y++
      ) {
        selectedRows.add(y);
      }
    }
    if (selectedRows.isEmpty) {
      return null;
    }

    final rows = selectedRows.toList()..sort();
    for (var x = 0; x < image.width; x++) {
      final samples = <double>[];
      final rowStep = math.max(1, rows.length ~/ 900);
      for (var i = 0; i < rows.length; i += rowStep) {
        final rgb = _correctedRgb(image.getPixel(x, rows[i]), gains);
        final hsv = _rgbToHsv(rgb[0], rgb[1], rgb[2]);
        final chroma = _rgbChroma(rgb[0], rgb[1], rgb[2]);
        final activity = hsv[1] > 0.12 && hsv[2] > 0.10 && hsv[2] < 0.985
            ? 1.0
            : 0.0;
        samples.add((0.58 * activity) + (0.42 * chroma));
      }
      colScores[x] = samples.isEmpty ? 0.0 : _mean(samples);
    }

    final smoothed = _smooth(colScores, math.max(7, padSize ~/ 8));
    final threshold = math.max(0.05, _percentile(smoothed, 94) * 0.45);
    final runs = _runs(smoothed.map((v) => v >= threshold).toList())
        .where(
          (run) =>
              run.length >= math.max(12, (padSize * 0.35).round()) &&
              run.length <= math.max(13, (padSize * 2.2).round()),
        )
        .toList();
    if (runs.isEmpty) {
      return null;
    }

    final stripCenter = strip.left + strip.width / 2.0;
    _Run? best;
    var bestScore = -double.infinity;
    for (final run in runs) {
      final strength = _mean(smoothed.sublist(run.start, run.end + 1));
      final center = (run.start + run.end) / 2.0;
      final distancePenalty = (center - stripCenter).abs() / image.width;
      final score = strength - distancePenalty;
      if (score > bestScore) {
        bestScore = score;
        best = run;
      }
    }
    if (best == null) {
      return null;
    }
    return (((best.start + best.end) / 2.0) - padSize / 2.0).round();
  }

  List<_Run> _bestConsecutiveRuns(
    List<_Run> runs,
    List<double> score,
    int count,
  ) {
    runs.sort((a, b) => a.start.compareTo(b.start));
    var bestScore = -double.infinity;
    List<_Run>? best;
    for (var start = 0; start <= runs.length - count; start++) {
      final window = runs.sublist(start, start + count);
      final centers = window.map((r) => (r.start + r.end) / 2.0).toList();
      final gaps = <double>[];
      for (var i = 1; i < centers.length; i++) {
        gaps.add(centers[i] - centers[i - 1]);
      }
      final gapMedian = _median(gaps);
      final gapCv = gapMedian <= 0 ? 999.0 : _stdDev(gaps) / gapMedian;
      if (gapCv > 0.24 ||
          gapMedian <= 0 ||
          gaps.any((gap) => gap < gapMedian * .60 || gap > gapMedian * 1.40)) {
        continue;
      }
      final strength = _mean(
        window.map((r) => _mean(score.sublist(r.start, r.end + 1))).toList(),
      );
      // Prefer the topmost valid ten-pad sequence. Some Cabatuan warm images
      // include extra pad-like regions; a stronger lower window would shift
      // every analyte label downward.
      final topWindowPenalty = start * 0.35;
      final s = strength - gapCv * 1.5 - topWindowPenalty;
      if (s > bestScore) {
        bestScore = s;
        best = window;
      }
    }
    if (best == null) {
      throw StateError('INVALID_IMAGE: No regular ten-pad sequence was found.');
    }
    return best;
  }

  List<double> _grayWorldGains(img.Image image, _Rect rect) {
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    var count = 0;
    final mx = math.max(4, (rect.width * 0.15).round());
    final my = math.max(8, (rect.height * 0.04).round());
    final x0 = math.max(0, rect.left - mx);
    final x1 = math.min(image.width - 1, rect.left + rect.width + mx);
    final y0 = math.max(0, rect.top - my);
    final y1 = math.min(image.height - 1, rect.top + rect.height + my);
    final step = math.max(1, math.min(x1 - x0 + 1, y1 - y0 + 1) ~/ 80);
    for (var y = y0; y <= y1; y += step) {
      for (var x = x0; x <= x1; x += step) {
        final p = image.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        if (hsv[1] < 0.28 && hsv[2] > 0.35 && hsv[2] < 0.98) {
          r += p.r.toDouble();
          g += p.g.toDouble();
          b += p.b.toDouble();
          count++;
        }
      }
    }
    if (count < 20) return [1.0, 1.0, 1.0];
    r = math.max(1.0, r / count);
    g = math.max(1.0, g / count);
    b = math.max(1.0, b / count);
    final target = (r + g + b) / 3.0;
    return [target / r, target / g, target / b];
  }

  void _validateReadableCapture(_FeatureExtraction extraction) {
    if (extraction.featuresByAnalyte.length != _analyteOrder.length) {
      throw StateError('INVALID_IMAGE: The full ten-pad strip was not found.');
    }
    final centers = [
      for (final analyte in _analyteOrder)
        extraction.padRois[analyte]!.top +
            extraction.padRois[analyte]!.height / 2.0,
    ];
    final gaps = [
      for (var i = 1; i < centers.length; i++) centers[i] - centers[i - 1],
    ];
    final medianGap = _median(gaps);
    if (medianGap <= 0 ||
        gaps.any((gap) => gap < medianGap * .60 || gap > medianGap * 1.40)) {
      throw StateError(
        'INVALID_IMAGE: A pad is missing or a background region was selected.',
      );
    }
    if (extraction.padGapCv > 0.24) {
      throw StateError('INVALID_IMAGE: Reagent-pad spacing is inconsistent.');
    }
    if (extraction.saturationMean < 0.018 &&
        extraction.saturationStd < 0.010 &&
        extraction.valueStd < 0.020) {
      throw StateError(
        'INVALID_IMAGE: Image does not contain readable reagent colors.',
      );
    }
    final stripTooSmall =
        extraction.stripRect.height < extraction.imageHeight * 0.35 ||
        extraction.stripRect.width < extraction.imageWidth * 0.015;
    if (stripTooSmall) {
      throw StateError(
        'INVALID_IMAGE: Strip is partial or too small in frame.',
      );
    }
    for (final roi in extraction.padRois.values) {
      final roiInsideX =
          roi.left >= extraction.stripRect.left - extraction.stripRect.width &&
          roi.left + roi.width <=
              extraction.stripRect.left + extraction.stripRect.width * 2;
      final roiInsideY =
          roi.top >= extraction.stripRect.top - roi.height &&
          roi.top + roi.height <=
              extraction.stripRect.top +
                  extraction.stripRect.height +
                  roi.height;
      if (!roiInsideX || !roiInsideY) {
        throw StateError(
          'INVALID_IMAGE: Pad ROIs do not align with the detected strip.',
        );
      }
    }
  }

  Map<String, List<double>> _normalizeHsvFeatures(
    Map<String, List<double>> raw,
  ) {
    final hues = raw.values.map((v) => v[0]).toList();
    final sats = raw.values.map((v) => v[1]).toList();
    final vals = raw.values.map((v) => v[2]).toList();
    final hueAnchor = _circularMeanDeg(hues);
    final satAnchor = _mean(sats);
    final valAnchor = _mean(vals);
    return raw.map((analyte, hsv) {
      return MapEntry(analyte, [
        _normalizeHue(hsv[0] - hueAnchor),
        (0.5 + (hsv[1] - satAnchor)).clamp(0.0, 1.0).toDouble(),
        (0.5 + (hsv[2] - valAnchor)).clamp(0.0, 1.0).toDouble(),
      ]);
    });
  }

  List<double> _meanHsv(img.Image image, _Rect rect, List<double> gains) {
    var sinH = 0.0;
    var cosH = 0.0;
    var sumS = 0.0;
    var sumV = 0.0;
    var count = 0;
    final step = math.max(1, math.min(rect.width, rect.height) ~/ 12);
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
    final hue = _normalizeHue(math.atan2(sinH, cosH) * 180.0 / math.pi);
    return [hue, sumS / count, sumV / count];
  }
}

// A bound method avoids capturing UI callbacks/receive ports in the worker.
class _AnalysisRequest {
  final String imagePath, modelText, policyText;
  final SendPort? port;
  const _AnalysisRequest(
    this.imagePath,
    this.modelText,
    this.policyText,
    this.port,
  );
  Map<String, dynamic> run() {
    try {
      return _analyzeScanInBackground(imagePath, modelText, policyText, port);
    } finally {
      port?.send({'done': true});
    }
  }
}

Map<String, dynamic> _analyzeScanInBackground(
  String imagePath,
  String modelText,
  String policyText,
  SendPort? localizationPort,
) {
  final service = const LocalScanAnalysisService();
  final model = _ProductionModel.fromText(modelText);
  final support = TrainingSupportPolicy.fromText(modelText, policyText);
  final imageBytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw StateError('INVALID_IMAGE: Could not decode captured image.');
  }

  final baseImage = service._imageForAnalysis(img.bakeOrientation(decoded));
  localizationPort?.send({
    'preview': img.encodeJpg(baseImage, quality: 85),
    'width': baseImage.width,
    'height': baseImage.height,
    'regions': <Map<String, Object>>[],
  });
  final extraction = service._extractBestPadFeatures(baseImage);
  if (localizationPort != null) {
    // Use the exact selected detector orientation, not a separate UI guess.
    final name = extraction.variantName;
    final preview = name.startsWith('rot90_cw')
        ? img.copyRotate(baseImage, angle: 90)
        : name.startsWith('rot90_ccw')
        ? img.copyRotate(baseImage, angle: -90)
        : name.startsWith('rot180')
        ? img.copyRotate(baseImage, angle: 180)
        : baseImage;
    localizationPort.send({
      'preview': img.encodeJpg(preview, quality: 85),
      'orientation': extraction.variantName,
      'width': extraction.imageWidth,
      'height': extraction.imageHeight,
      'regions': [
        for (final entry in extraction.padRois.entries)
          {
            'label': _codeForAnalyte(entry.key),
            'left': entry.value.left,
            'top': entry.value.top,
            'width': entry.value.width,
            'height': entry.value.height,
          },
      ],
    });
  }
  final rows = <DipstickResultRow>[];
  final confidenceValues = <double>[];
  final confidenceByAnalyte = <String, double>{};
  final distancesByAnalyte = <String, double>{};

  for (final analyte in _analyteOrder) {
    final prediction = model.predict(analyte, extraction.featuresByAnalyte);
    support.validate(analyte, prediction.nearestDistance);
    distancesByAnalyte[analyte] = prediction.nearestDistance;
    final displayLevel = _normalizeDisplayLevel(prediction.level);
    confidenceValues.add(prediction.confidence);
    confidenceByAnalyte[analyte] = prediction.confidence;
    rows.add(
      DipstickResultRow(
        code: _codeForAnalyte(analyte),
        name: analyte,
        result: displayLevel,
        referenceRange: _referenceRanges[analyte] ?? 'Reference unavailable',
        status: _isDisplayValueAbnormal(displayLevel)
            ? DipstickResultStatus.moderate
            : DipstickResultStatus.negative,
      ),
    );
  }
  model.validateConfidence(confidenceByAnalyte);

  final averageConfidence = confidenceValues.isEmpty
      ? 0.0
      : confidenceValues.reduce((a, b) => a + b) / confidenceValues.length;

  return ScanResult(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      imagePath: imagePath,
      status: 'complete',
      confidence: averageConfidence,
      analyteConfidences: confidenceByAnalyte,
      supportCheckPassed: true,
      nearestTrainingDistances: distancesByAnalyte,
      riskBucket: 'Complete',
      modelVersion: model.version,
      rows: rows,
      padsDetected: extraction.featuresByAnalyte.length,
      padsUnavailable:
          _analyteOrder.length - extraction.featuresByAnalyte.length,
    ).toJson()
    ..['pipeline_version'] = 'android_markerless_json_knn_v4_support_20261010'
    ..['feature_space'] = 'normalized_hsv'
    ..['localization'] = 'markerless_strip_v1'
    ..['orientation'] = extraction.variantName;
}

class _ProductionModel {
  final String version;
  final bool abstainEnabled;
  final double abstainThreshold;
  final Map<String, _AnalyteModel> analytes;

  const _ProductionModel({
    required this.version,
    required this.abstainEnabled,
    required this.abstainThreshold,
    required this.analytes,
  });

  static _ProductionModel fromText(String text) {
    final payload = jsonDecode(text) as Map<String, dynamic>;
    final analytesJson = payload['analytes'] as Map<String, dynamic>? ?? {};
    final abstainPolicy =
        payload['abstain_policy'] as Map<String, dynamic>? ?? {};
    return _ProductionModel(
      version: payload['model_version'] as String? ?? 'production_unknown',
      abstainEnabled: abstainPolicy['enabled'] as bool? ?? false,
      abstainThreshold: (abstainPolicy['threshold'] as num?)?.toDouble() ?? 0.0,
      analytes: analytesJson.map((key, value) {
        return MapEntry(
          key,
          _AnalyteModel.fromJson(value as Map<String, dynamic>),
        );
      }),
    );
  }

  _Prediction predict(
    String analyte,
    Map<String, List<double>> featuresByAnalyte,
  ) {
    final model = analytes[analyte];
    final observed = featuresByAnalyte[analyte];
    if (model == null || observed == null) {
      return const _Prediction(level: 'Unavailable', confidence: 0.0);
    }
    return model.predict(analyte, featuresByAnalyte);
  }

  void validateConfidence(Map<String, double> confidenceByAnalyte) {
    if (!abstainEnabled || abstainThreshold <= 0.0) return;
    final lowConfidence =
        confidenceByAnalyte.entries
            .where((entry) => entry.value < abstainThreshold)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    if (lowConfidence.isEmpty) return;

    final analyte = lowConfidence.first.key;
    throw ScanAnalysisFailure(
      code: 'LOW_CONFIDENCE',
      guidance:
          'All ten pads were located, but the $analyte pad could not be classified confidently. Retake under even lighting, with the strip in focus.',
      padsDetected: _analyteOrder.length,
    );
  }
}

class _AnalyteModel {
  final int k;
  final String metric;
  final String weights;
  final String featureSet;
  final String featureTransform;
  final List<double>? scalerMean;
  final List<double>? scalerScale;
  final List<List<double>> trainVectors;
  final List<String> trainLabels;

  const _AnalyteModel({
    required this.k,
    required this.metric,
    required this.weights,
    required this.featureSet,
    required this.featureTransform,
    required this.scalerMean,
    required this.scalerScale,
    required this.trainVectors,
    required this.trainLabels,
  });

  static _AnalyteModel fromJson(Map<String, dynamic> json) {
    final scaler = json['scaler'] as Map<String, dynamic>?;
    return _AnalyteModel(
      k: (json['k'] as num?)?.round() ?? 1,
      metric: json['metric'] as String? ?? 'euclidean',
      weights: json['weights'] as String? ?? 'distance',
      featureSet: json['feature_set'] as String? ?? 'local',
      featureTransform: json['feature_transform'] as String? ?? 'raw',
      scalerMean: (scaler?['mean'] as List<dynamic>?)
          ?.map((v) => (v as num).toDouble())
          .toList(growable: false),
      scalerScale: (scaler?['scale'] as List<dynamic>?)
          ?.map((v) => (v as num).toDouble())
          .toList(growable: false),
      trainVectors: (json['train_vectors'] as List<dynamic>)
          .map(
            (row) => (row as List<dynamic>)
                .map((v) => (v as num).toDouble())
                .toList(growable: false),
          )
          .toList(growable: false),
      trainLabels: (json['train_labels'] as List<dynamic>)
          .map((v) => v.toString())
          .toList(growable: false),
    );
  }

  _Prediction predict(
    String analyte,
    Map<String, List<double>> featuresByAnalyte,
  ) {
    final observed = _observedVector(analyte, featuresByAnalyte);
    if (observed.isEmpty) {
      return const _Prediction(level: 'Unavailable', confidence: 0.0);
    }
    final transformed = _transform(observed);
    if (transformed.any((v) => !v.isFinite) ||
        trainVectors.any((v) => v.length != transformed.length)) {
      throw StateError('Invalid model feature dimensions or values.');
    }
    final distances = <_Neighbor>[];
    for (var i = 0; i < trainVectors.length; i++) {
      distances.add(
        _Neighbor(trainLabels[i], _distance(transformed, trainVectors[i])),
      );
    }
    distances.sort((a, b) => a.distance.compareTo(b.distance));
    final votes = <String, double>{};
    for (final neighbor in distances.take(math.min(k, distances.length))) {
      final vote = weights == 'distance'
          ? 1.0 / (neighbor.distance + 1e-9)
          : 1.0;
      votes[neighbor.label] = (votes[neighbor.label] ?? 0.0) + vote;
    }
    final ranked = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return const _Prediction(level: 'Unavailable', confidence: 0.0);
    }
    final total = ranked.fold<double>(0.0, (sum, item) => sum + item.value);
    return _Prediction(
      level: ranked.first.key,
      confidence: total <= 0 ? 0.0 : ranked.first.value / total,
      nearestDistance: distances.first.distance,
    );
  }

  List<double> _observedVector(
    String analyte,
    Map<String, List<double>> featuresByAnalyte,
  ) {
    if (featureSet == 'all30') {
      final values = <double>[];
      for (final item in _analyteOrder) {
        final hsv = featuresByAnalyte[item];
        if (hsv == null) return const [];
        values.addAll(hsv);
      }
      return values;
    }
    return featuresByAnalyte[analyte] ?? const [];
  }

  List<double> _transform(List<double> values) {
    var transformed = values;
    if (featureTransform == 'circular_scaled') {
      final radians = values[0] * math.pi / 180.0;
      transformed = [
        math.cos(radians),
        math.sin(radians),
        values[1],
        values[2],
      ];
    }
    if (featureTransform == 'scaled' || featureTransform == 'circular_scaled') {
      final mean = scalerMean;
      final scale = scalerScale;
      if (mean != null && scale != null && mean.length == transformed.length) {
        return [
          for (var i = 0; i < transformed.length; i++)
            (transformed[i] - mean[i]) / (scale[i] == 0.0 ? 1.0 : scale[i]),
        ];
      }
    }
    return transformed;
  }

  double _distance(List<double> a, List<double> b) {
    if (metric == 'manhattan') {
      var total = 0.0;
      for (var i = 0; i < a.length; i++) {
        total += (a[i] - b[i]).abs();
      }
      return total;
    }
    if (metric == 'chebyshev') {
      var maxDelta = 0.0;
      for (var i = 0; i < a.length; i++) {
        maxDelta = math.max(maxDelta, (a[i] - b[i]).abs());
      }
      return maxDelta;
    }
    var total = 0.0;
    for (var i = 0; i < a.length; i++) {
      final delta = a[i] - b[i];
      total += delta * delta;
    }
    return math.sqrt(total);
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
  final Map<String, List<double>> rawFeaturesByAnalyte;
  final Map<String, _Rect> padRois;
  final _StripRect stripRect;
  final int imageWidth;
  final int imageHeight;
  final double qualityScore;
  final double padGapCv;
  final double hueStd;
  final double saturationMean;
  final double saturationStd;
  final double valueStd;

  const _FeatureExtraction({
    required this.variantName,
    required this.featuresByAnalyte,
    required this.rawFeaturesByAnalyte,
    required this.padRois,
    required this.stripRect,
    required this.imageWidth,
    required this.imageHeight,
    required this.qualityScore,
    required this.padGapCv,
    required this.hueStd,
    required this.saturationMean,
    required this.saturationStd,
    required this.valueStd,
  });
}

class _Neighbor {
  final String label;
  final double distance;
  const _Neighbor(this.label, this.distance);
}

class _Prediction {
  final String level;
  final double confidence;
  final double nearestDistance;
  const _Prediction({
    required this.level,
    required this.confidence,
    this.nearestDistance = double.infinity,
  });
}

class _Run {
  final int start;
  final int end;
  int get length => end - start + 1;
  const _Run(this.start, this.end);
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

class _StripRect extends _Rect {
  final double quality;
  const _StripRect({
    required super.left,
    required super.top,
    required super.width,
    required super.height,
    required super.area,
    required this.quality,
  });
}

List<_Run> _runs(List<bool> flags) {
  final runs = <_Run>[];
  int? start;
  for (var i = 0; i <= flags.length; i++) {
    final flag = i < flags.length ? flags[i] : false;
    if (flag && start == null) {
      start = i;
    } else if (!flag && start != null) {
      runs.add(_Run(start, i - 1));
      start = null;
    }
  }
  return runs;
}

List<double> _smooth(List<double> values, int window) {
  final w = math.max(3, window.isEven ? window + 1 : window);
  final half = w ~/ 2;
  return [
    for (var i = 0; i < values.length; i++)
      _mean(
        values.sublist(
          math.max(0, i - half),
          math.min(values.length, i + half + 1),
        ),
      ),
  ];
}

double _percentile(List<double> values, double percentile) {
  if (values.isEmpty) return 0.0;
  final sorted = values.toList()..sort();
  final index = ((percentile / 100.0) * (sorted.length - 1)).round();
  return sorted[index.clamp(0, sorted.length - 1).toInt()];
}

double _mean(List<double> values) =>
    values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

double _median(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

double _stdDev(List<double> values) {
  if (values.length < 2) return 0.0;
  final m = _mean(values);
  return math.sqrt(
    _mean(values.map((v) => math.pow(v - m, 2).toDouble()).toList()),
  );
}

double _circularMeanDeg(List<double> values) {
  var sinSum = 0.0;
  var cosSum = 0.0;
  for (final hue in values) {
    final radians = hue * math.pi / 180.0;
    sinSum += math.sin(radians);
    cosSum += math.cos(radians);
  }
  return _normalizeHue(math.atan2(sinSum, cosSum) * 180.0 / math.pi);
}

double _circularHueStd(List<double> hues) {
  if (hues.length < 2) return 0.0;
  var sinSum = 0.0;
  var cosSum = 0.0;
  for (final hue in hues) {
    final radians = hue * math.pi / 180.0;
    sinSum += math.sin(radians);
    cosSum += math.cos(radians);
  }
  final r = (math.sqrt(sinSum * sinSum + cosSum * cosSum) / hues.length)
      .clamp(0.000001, 1.0)
      .toDouble();
  return math.sqrt(-2.0 * math.log(r)) * 180.0 / math.pi;
}

double _normalizeHue(double hue) {
  var normalized = hue % 360.0;
  if (normalized < 0) normalized += 360.0;
  return normalized;
}

List<double> _correctedRgb(img.Pixel pixel, List<double> gains) {
  return [
    (pixel.r.toDouble() * gains[0]).clamp(0.0, 255.0).toDouble(),
    (pixel.g.toDouble() * gains[1]).clamp(0.0, 255.0).toDouble(),
    (pixel.b.toDouble() * gains[2]).clamp(0.0, 255.0).toDouble(),
  ];
}

double _rgbChroma(double r, double g, double b) {
  final maxValue = math.max(r, math.max(g, b));
  final minValue = math.min(r, math.min(g, b));
  return ((maxValue - minValue) / 255.0).clamp(0.0, 1.0).toDouble();
}

double _luma(img.Pixel pixel) =>
    (0.2126 * pixel.r) + (0.7152 * pixel.g) + (0.0722 * pixel.b);

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
  return [_normalizeHue(hue), maxValue == 0 ? 0.0 : delta / maxValue, maxValue];
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
  if (normalized.toLowerCase() == 'neg') return 'Negative';
  return normalized.isEmpty ? 'Unavailable' : normalized;
}

bool _isDisplayValueAbnormal(String level) {
  final normalized = level.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'unavailable') return false;
  return normalized != 'neg' && normalized != 'negative';
}
