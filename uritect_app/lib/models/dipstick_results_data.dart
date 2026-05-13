import 'package:flutter/material.dart';

class DipstickResultRow {
  final String code;
  final String name;
  final String result;
  final String referenceRange;
  final DipstickResultStatus status;

  const DipstickResultRow({
    required this.code,
    required this.name,
    required this.result,
    required this.referenceRange,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'result': result,
      'referenceRange': referenceRange,
      'status': status.name,
    };
  }

  factory DipstickResultRow.fromJson(Map<String, dynamic> json) {
    return DipstickResultRow(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      result: json['result'] as String? ?? 'Unavailable',
      referenceRange: json['referenceRange'] as String? ?? '',
      status: json['status'] == DipstickResultStatus.moderate.name
          ? DipstickResultStatus.moderate
          : DipstickResultStatus.negative,
    );
  }
}

enum DipstickResultStatus { moderate, negative }

const List<DipstickResultRow> sampleDipstickRows = [
  DipstickResultRow(
    code: 'LEU',
    name: 'Leukocytes',
    result: 'Moderate',
    referenceRange: 'Negative',
    status: DipstickResultStatus.moderate,
  ),
  DipstickResultRow(
    code: 'NIT',
    name: 'Nitrite',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'URO',
    name: 'Urobilinogen',
    result: 'Negative',
    referenceRange: '3.2 - 128',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'PRO',
    name: 'Protein',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'pH',
    name: 'pH',
    result: 'Negative',
    referenceRange: '5.0 - 8.5',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'BLD',
    name: 'Blood',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'SG',
    name: 'Specific Gravity',
    result: 'Negative',
    referenceRange: '1.000 - 1.030',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'KET',
    name: 'Ketones',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'BIL',
    name: 'Bilirubin',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
  DipstickResultRow(
    code: 'GLU',
    name: 'Glucose',
    result: 'Negative',
    referenceRange: 'Negative',
    status: DipstickResultStatus.negative,
  ),
];

Color dipstickCodeColor(String code) {
  switch (code) {
    case 'LEU':
      return const Color(0xFFDD73D5);
    case 'NIT':
      return const Color(0xFF9A70E8);
    case 'URO':
      return const Color(0xFF4F86F7);
    case 'PRO':
      return const Color(0xFF3CA0F0);
    case 'pH':
      return const Color(0xFF55C17A);
    case 'BLD':
      return const Color(0xFFFF7770);
    case 'SG':
      return const Color(0xFF60B4F3);
    case 'KET':
      return const Color(0xFFFFA24D);
    case 'BIL':
      return const Color(0xFFE8D35D);
    case 'GLU':
      return const Color(0xFFFF7C93);
    default:
      return const Color(0xFF1D87A3);
  }
}
