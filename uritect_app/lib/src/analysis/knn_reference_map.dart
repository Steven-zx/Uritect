import 'dart:math' as math;

import 'package:flutter/material.dart';

class ParameterThreshold {
  const ParameterThreshold({
    required this.level,
    required this.referenceColor,
    required this.weight,
  });

  final String level;
  final Color referenceColor;
  final double weight;
}

class KnnReferenceMap {
  const KnnReferenceMap({
    required this.map,
  });

  final Map<String, List<ParameterThreshold>> map;

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

    for (final candidate in candidates) {
      final distance = _euclideanDistanceRgb(
        observedColor,
        candidate.referenceColor,
      );
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
}
