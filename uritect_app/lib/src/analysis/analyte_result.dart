import 'dart:ui' as ui;
import 'dart:typed_data';

class AnalyteResult {
  const AnalyteResult({
    required this.analyteName,
    required this.rawRgb,
    required this.correctedRgb,
    required this.hsv,
    required this.sampleCenter,
    required this.sampledCropPng,
    required this.nearestMatch,
  });

  final String analyteName;
  final ui.Color rawRgb;
  final ui.Color correctedRgb;
  final ui.HSVColor hsv;
  final ui.Offset sampleCenter;
  final Uint8List sampledCropPng;
  final String nearestMatch;
}
