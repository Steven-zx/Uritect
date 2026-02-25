import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'analyte_result.dart';
import 'knn_reference_map.dart';

class ColorProcessorService {
  const ColorProcessorService();

  static const List<String> defaultAnalyteOrder = [
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

  Future<List<AnalyteResult>> extractPadColors(
    File image,
    List<ui.Offset> roiCenters, {
    required double awbGainR,
    required double awbGainG,
    required double awbGainB,
    List<String> analyteOrder = defaultAnalyteOrder,
    int kernelSize = 10,
    KnnReferenceMap? knnReferenceMap,
  }) async {
    if (roiCenters.length != 10) {
      throw ArgumentError('extractPadColors expects exactly 10 ROI center coordinates.');
    }

    if (analyteOrder.length != 10) {
      throw ArgumentError('analyteOrder must contain exactly 10 analyte names.');
    }

    if (kernelSize <= 0 || kernelSize.isOdd) {
      throw ArgumentError('kernelSize must be a positive even number (e.g., 10).');
    }

    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Unable to decode image for color processing: ${image.path}');
    }

    final results = <AnalyteResult>[];

    for (var index = 0; index < roiCenters.length; index++) {
      final center = _resolveCenter(
        roiCenters[index],
        imageWidth: decoded.width,
        imageHeight: decoded.height,
      );

      final rawMean = _sampleMeanRgb(
        image: decoded,
        centerX: center.dx,
        centerY: center.dy,
        kernelSize: kernelSize,
      );

      final correctedMean = _applyAwbGains(
        rawMean,
        gainR: awbGainR,
        gainG: awbGainG,
        gainB: awbGainB,
      );

      final correctedColor = ui.Color.fromARGB(
        255,
        correctedMean.r,
        correctedMean.g,
        correctedMean.b,
      );

      final hsv = ui.HSVColor.fromColor(correctedColor);
      final cropPng = _extractKernelCropPng(
        image: decoded,
        centerX: center.dx,
        centerY: center.dy,
        kernelSize: kernelSize,
      );

      final analyteName = analyteOrder[index];
      final nearest = knnReferenceMap?.findNearestNeighbor(
        parameterName: analyteName,
        observedColor: correctedColor,
      );
      final nearestMatch = nearest == null ? '$analyteName: Pending' : '$analyteName: ${nearest.level}';

      results.add(
        AnalyteResult(
          analyteName: analyteName,
          rawRgb: ui.Color.fromARGB(255, rawMean.r, rawMean.g, rawMean.b),
          correctedRgb: correctedColor,
          hsv: hsv,
          sampleCenter: center,
          sampledCropPng: cropPng,
          nearestMatch: nearestMatch,
        ),
      );
    }

    return results;
  }

  ui.Offset _resolveCenter(
    ui.Offset input, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final looksNormalized =
        input.dx >= 0 && input.dx <= 1 && input.dy >= 0 && input.dy <= 1;

    final pixelX = looksNormalized ? input.dx * imageWidth : input.dx;
    final pixelY = looksNormalized ? input.dy * imageHeight : input.dy;

    return ui.Offset(
      pixelX.clamp(0, imageWidth - 1).toDouble(),
      pixelY.clamp(0, imageHeight - 1).toDouble(),
    );
  }

  _RgbSample _sampleMeanRgb({
    required img.Image image,
    required double centerX,
    required double centerY,
    required int kernelSize,
  }) {
    final half = kernelSize ~/ 2;
    final originX = centerX.round() - half;
    final originY = centerY.round() - half;

    var sumR = 0.0;
    var sumG = 0.0;
    var sumB = 0.0;

    for (var dy = 0; dy < kernelSize; dy++) {
      for (var dx = 0; dx < kernelSize; dx++) {
        final x = (originX + dx).clamp(0, image.width - 1);
        final y = (originY + dy).clamp(0, image.height - 1);

        final pixel = image.getPixel(x, y);
        sumR += pixel.r;
        sumG += pixel.g;
        sumB += pixel.b;
      }
    }

    final count = (kernelSize * kernelSize).toDouble();
    return _RgbSample(
      r: (sumR / count).round().clamp(0, 255),
      g: (sumG / count).round().clamp(0, 255),
      b: (sumB / count).round().clamp(0, 255),
    );
  }

  Uint8List _extractKernelCropPng({
    required img.Image image,
    required double centerX,
    required double centerY,
    required int kernelSize,
  }) {
    final half = kernelSize ~/ 2;
    final originX = centerX.round() - half;
    final originY = centerY.round() - half;

    final safeX = originX.clamp(0, math.max(0, image.width - kernelSize));
    final safeY = originY.clamp(0, math.max(0, image.height - kernelSize));
    final safeWidth = math.min(kernelSize, image.width);
    final safeHeight = math.min(kernelSize, image.height);

    final crop = img.copyCrop(
      image,
      x: safeX,
      y: safeY,
      width: safeWidth,
      height: safeHeight,
    );

    return Uint8List.fromList(img.encodePng(crop));
  }

  _RgbSample _applyAwbGains(
    _RgbSample input, {
    required double gainR,
    required double gainG,
    required double gainB,
  }) {
    return _RgbSample(
      r: (input.r * gainR).round().clamp(0, 255),
      g: (input.g * gainG).round().clamp(0, 255),
      b: (input.b * gainB).round().clamp(0, 255),
    );
  }

  double colorDistanceRgb(ui.Color a, ui.Color b) {
    final dr = (a.r - b.r).toDouble();
    final dg = (a.g - b.g).toDouble();
    final db = (a.b - b.b).toDouble();
    return math.sqrt((dr * dr) + (dg * dg) + (db * db));
  }
}

class _RgbSample {
  const _RgbSample({
    required this.r,
    required this.g,
    required this.b,
  });

  final int r;
  final int g;
  final int b;
}
