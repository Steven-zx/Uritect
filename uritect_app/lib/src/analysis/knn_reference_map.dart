import 'dart:math' as math;

import 'package:flutter/material.dart';

class ParameterThreshold {
  const ParameterThreshold({
    required this.level,
    required this.referenceColor,
    required this.weight,
    this.referenceHsv,
  });

  final String level;
  final Color referenceColor;
  final double weight;
  final HSVColor? referenceHsv;
}

class KnnReferenceMap {
  const KnnReferenceMap({
    required this.map,
  });

  final Map<String, List<ParameterThreshold>> map;

  factory KnnReferenceMap.fromJson(Map<String, dynamic> json) {
    final analytesJson =
        (json['analytes'] as Map<String, dynamic>?) ?? {};
    final map = <String, List<ParameterThreshold>>{};
    for (final entry in analytesJson.entries) {
      if (entry.value is! List<dynamic>) {
        continue;
      }

      final levelsList = entry.value as List<dynamic>;
      final thresholds = <ParameterThreshold>[];

      for (final item in levelsList) {
        if (item is! Map) {
          continue;
        }

        final m = Map<String, dynamic>.from(item);
        final level = m['level'];
        if (level is! String || level.trim().isEmpty) {
          continue;
        }

        final referenceHsv = _parseReferenceHsv(m);
        final referenceRgb = _parseReferenceRgb(m);
        if (referenceHsv == null && referenceRgb == null) {
          continue;
        }

        thresholds.add(
          ParameterThreshold(
            level: level,
            referenceColor: referenceHsv?.toColor() ?? referenceRgb!,
            weight: (m['weight'] as num?)?.toDouble() ?? 1.0,
            referenceHsv: referenceHsv,
          ),
        );
      }

      if (thresholds.isNotEmpty) {
        map[entry.key] = thresholds;
      }
    }
    return KnnReferenceMap(map: map);
  }

  ParameterThreshold? findNearestNeighbor({
    required String parameterName,
    required Color observedColor,
  }) {
    final candidates = map[parameterName];
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    ParameterThreshold? best;
    var bestDistance = double.infinity;
    final observedHsv = HSVColor.fromColor(observedColor);

    for (final candidate in candidates) {
      final distance = candidate.referenceHsv != null
          ? _euclideanDistanceHsv(observedHsv, candidate.referenceHsv!)
          : _euclideanDistanceRgb(observedColor, candidate.referenceColor);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    return best;
  }

  double _euclideanDistanceRgb(Color a, Color b) {
    final dr = (a.r - b.r).toDouble();
    final dg = (a.g - b.g).toDouble();
    final db = (a.b - b.b).toDouble();

    return math.sqrt((dr * dr) + (dg * dg) + (db * db));
  }

  double _euclideanDistanceHsv(HSVColor a, HSVColor b) {
    final rawHueDelta = (a.hue - b.hue).abs();
    final hueDelta = math.min(rawHueDelta, 360.0 - rawHueDelta) / 180.0;
    final saturationDelta = a.saturation - b.saturation;
    final valueDelta = a.value - b.value;

    return math.sqrt(
      (hueDelta * hueDelta) +
          (saturationDelta * saturationDelta) +
          (valueDelta * valueDelta),
    );
  }

  static Color? _parseReferenceRgb(Map<String, dynamic> json) {
    final r = _asDouble(json['r']);
    final g = _asDouble(json['g']);
    final b = _asDouble(json['b']);
    if (r == null || g == null || b == null) {
      return null;
    }

    return Color.fromARGB(
      255,
      r.round().clamp(0, 255),
      g.round().clamp(0, 255),
      b.round().clamp(0, 255),
    );
  }

  static HSVColor? _parseReferenceHsv(Map<String, dynamic> json) {
    final h = _asDouble(json['h']);
    final s = _asDouble(json['s']);
    final v = _asDouble(json['v']);
    if (h == null || s == null || v == null) {
      return null;
    }

    return HSVColor.fromAHSV(
      1.0,
      _normalizeHue(h),
      _clip01(s),
      _clip01(v),
    );
  }

  static double _clip01(double value) {
    if (value < 0) {
      return 0.0;
    }
    if (value > 1) {
      return 1.0;
    }
    return value;
  }

  static double _normalizeHue(double hue) {
    final normalized = hue % 360.0;
    if (normalized < 0) {
      return normalized + 360.0;
    }
    return normalized;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
