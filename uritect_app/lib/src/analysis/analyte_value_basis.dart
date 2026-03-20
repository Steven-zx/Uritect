class AnalyteValueMapping {
  const AnalyteValueMapping({
    required this.unit,
    required this.levelToValue,
    required this.basisTag,
    required this.basisSummary,
  });

  final String unit;
  final Map<String, String> levelToValue;
  final String basisTag;
  final String basisSummary;
}

class AnalyteValueResolution {
  const AnalyteValueResolution({
    required this.analyteName,
    required this.matchedLevel,
    required this.displayValue,
    required this.unit,
    required this.basisTag,
    required this.basisSummary,
    required this.isMapped,
  });

  final String analyteName;
  final String matchedLevel;
  final String displayValue;
  final String unit;
  final String basisTag;
  final String basisSummary;
  final bool isMapped;
}

const String analyteValueProfileVersion = 'baseline_v1';

const String _defaultBasisTag = 'THESIS+SemiQuant baseline_v1';
const String _defaultBasisSummary =
    'Built from thesis priors plus standard semiquant urinalysis bins; replace with active strip IFU and lot card before clinical validation.';

const Map<String, AnalyteValueMapping> analyteValueBasisMap = {
  'Leukocytes': AnalyteValueMapping(
    unit: 'Leu/µL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '0',
      'Trace': '~15',
      '1+': '~70',
      '2+': '~125',
      '3+': '~500',
      'Positive': '>=70',
    },
  ),
  'Nitrite': AnalyteValueMapping(
    unit: 'qualitative',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': 'Negative',
      'Trace': 'Equivocal',
      '1+': 'Positive',
      'Positive': 'Positive',
    },
  ),
  'Urobilinogen': AnalyteValueMapping(
    unit: 'mg/dL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '0.2',
      'Trace': '0.2-1.0',
      '1+': '1',
      '2+': '2',
      '3+': '4',
      '4+': '8',
      'Positive': '>=1',
    },
  ),
  'Protein': AnalyteValueMapping(
    unit: 'mg/dL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '<15',
      'Trace': '~15',
      '1+': '~30',
      '2+': '~100',
      '3+': '~300',
      '4+': '>=1000',
      'Positive': '>=30',
    },
  ),
  'pH': AnalyteValueMapping(
    unit: 'pH',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '5.0-6.0',
      'Trace': '6.5-7.0',
      '1+': '7.5-8.0',
      '2+': '8.5',
      '3+': '>=9.0',
      '5.0': '5.0',
      '5.5': '5.5',
      '6.0': '6.0',
      '6.5': '6.5',
      '7.0': '7.0',
      '7.5': '7.5',
      '8.0': '8.0',
      '8.5': '8.5',
    },
  ),
  'Blood': AnalyteValueMapping(
    unit: 'RBC/µL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '0',
      'Trace': '~10',
      '1+': '~25',
      '2+': '~80',
      '3+': '~200',
      'Positive': '>=25',
    },
  ),
  'Specific Gravity': AnalyteValueMapping(
    unit: 'SG',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '1.000-1.010',
      'Trace': '1.015-1.020',
      '1+': '1.025-1.030',
      '2+': '>1.030',
      '1.000': '1.000',
      '1.005': '1.005',
      '1.010': '1.010',
      '1.015': '1.015',
      '1.020': '1.020',
      '1.025': '1.025',
      '1.030': '1.030',
    },
  ),
  'Ketone': AnalyteValueMapping(
    unit: 'mg/dL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '<5',
      'Trace': '~5',
      '1+': '~15',
      '2+': '~40',
      '3+': '~80',
      '4+': '~160',
      'Positive': '>=15',
    },
  ),
  'Bilirubin': AnalyteValueMapping(
    unit: 'mg/dL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '0',
      'Trace': '~0.5',
      '1+': '~1',
      '2+': '~2',
      '3+': '~4',
      'Positive': '>=1',
    },
  ),
  'Glucose': AnalyteValueMapping(
    unit: 'mg/dL',
    basisTag: _defaultBasisTag,
    basisSummary: _defaultBasisSummary,
    levelToValue: {
      'Negative': '<100',
      'Trace': '100-249',
      '1+': '250-499',
      '2+': '500-999',
      '3+': '1000-1999',
      '4+': '>=2000',
      'Positive': '>=100',
    },
  ),
};

String extractMatchedLevel({
  required String analyteName,
  required String nearestMatch,
}) {
  final delimiter = nearestMatch.indexOf(':');
  if (delimiter == -1) {
    return nearestMatch.trim();
  }

  final left = nearestMatch.substring(0, delimiter).trim();
  final right = nearestMatch.substring(delimiter + 1).trim();
  if (left.isEmpty || right.isEmpty) {
    return nearestMatch.trim();
  }

  if (left.toLowerCase() == analyteName.toLowerCase()) {
    return right;
  }

  return nearestMatch.trim();
}

AnalyteValueResolution resolveAnalyteValue({
  required String analyteName,
  required String nearestMatch,
}) {
  final matchedLevel = extractMatchedLevel(
    analyteName: analyteName,
    nearestMatch: nearestMatch,
  );

  final mapping = analyteValueBasisMap[analyteName];
  if (mapping == null) {
    return AnalyteValueResolution(
      analyteName: analyteName,
      matchedLevel: matchedLevel,
      displayValue: 'No configured value profile',
      unit: '-',
      basisTag: 'unmapped',
      basisSummary: 'No analyte profile found for this parameter.',
      isMapped: false,
    );
  }

  String? mappedValue;
  final normalizedLevel = matchedLevel.toLowerCase();
  for (final entry in mapping.levelToValue.entries) {
    if (entry.key.toLowerCase() == normalizedLevel) {
      mappedValue = entry.value;
      break;
    }
  }

  final hasValue = mappedValue != null && mappedValue.isNotEmpty;
  return AnalyteValueResolution(
    analyteName: analyteName,
    matchedLevel: matchedLevel,
    displayValue: hasValue ? mappedValue : 'No value mapping for "$matchedLevel"',
    unit: mapping.unit,
    basisTag: mapping.basisTag,
    basisSummary: mapping.basisSummary,
    isMapped: hasValue,
  );
}
