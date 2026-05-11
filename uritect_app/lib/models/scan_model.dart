class ScanResult {
  final String id;
  final DateTime date;
  final String status; // 'normal', 'moderate', 'critical'
  final double confidence;
  final Map<String, AnalyteResult> analytes;

  ScanResult({
    required this.id,
    required this.date,
    required this.status,
    required this.confidence,
    required this.analytes,
  });
}

class AnalyteResult {
  final String name;
  final String level;
  final String status; // 'normal', 'moderate', 'high'
  final String referenceRange;

  AnalyteResult({
    required this.name,
    required this.level,
    required this.status,
    required this.referenceRange,
  });
}
