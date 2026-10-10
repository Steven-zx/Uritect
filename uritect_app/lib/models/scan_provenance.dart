class ImageMatch {
  final String recordId;
  final bool exact;
  const ImageMatch(this.recordId, this.exact);
}

class ScanProvenance {
  final String source;
  final DateTime analyzedAt;
  final DateTime? capturedAt;
  final DateTime? reportedPhotoDate;
  final String contentSha256;
  final String pixelSha256;
  final String imageFingerprint;
  final String? duplicateOf;
  final String? similarImageOf;
  final String? specimenCode;
  final double? secondsAfterDipping;
  final bool currentSpecimenConfirmed;
  final bool duplicateCheckCompleted;

  const ScanProvenance({
    required this.source,
    required this.analyzedAt,
    this.capturedAt,
    this.reportedPhotoDate,
    required this.contentSha256,
    required this.pixelSha256,
    required this.imageFingerprint,
    this.duplicateOf,
    this.similarImageOf,
    this.specimenCode,
    this.secondsAfterDipping,
    this.currentSpecimenConfirmed = false,
    this.duplicateCheckCompleted = false,
  });

  bool get isImported => source == 'import';
  bool get isDuplicate => duplicateOf != null;
  bool get isEarlierPhoto =>
      reportedPhotoDate != null &&
      reportedPhotoDate!.isBefore(
        DateTime(analyzedAt.year, analyzedAt.month, analyzedAt.day),
      );
  bool get canSupportCurrentContext =>
      !isDuplicate &&
      !isEarlierPhoto &&
      duplicateCheckCompleted &&
      currentSpecimenConfirmed &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(contentSha256) &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(pixelSha256) &&
      RegExp(r'^[a-f0-9]{16}$').hasMatch(imageFingerprint) &&
      (source != 'camera' || capturedAt != null) &&
      (source == 'camera' || source == 'import') &&
      specimenCode != null &&
      specimenCode!.trim().isNotEmpty &&
      secondsAfterDipping != null &&
      secondsAfterDipping!.isFinite &&
      secondsAfterDipping! >= 0;

  Map<String, dynamic> toJson() => {
    'source': source,
    'analyzedAt': analyzedAt.toIso8601String(),
    'capturedAt': capturedAt?.toIso8601String(),
    'reportedPhotoDate': reportedPhotoDate?.toIso8601String(),
    'contentSha256': contentSha256,
    'pixelSha256': pixelSha256,
    'imageFingerprint': imageFingerprint,
    'duplicateOf': duplicateOf,
    'similarImageOf': similarImageOf,
    'specimenCode': specimenCode,
    'secondsAfterDipping': secondsAfterDipping,
    'currentSpecimenConfirmed': currentSpecimenConfirmed,
    'duplicateCheckCompleted': duplicateCheckCompleted,
  };
  factory ScanProvenance.fromJson(Map<String, dynamic> j) => ScanProvenance(
    source: j['source'] as String? ?? 'unknown',
    analyzedAt:
        DateTime.tryParse(j['analyzedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    capturedAt: DateTime.tryParse(j['capturedAt'] as String? ?? ''),
    reportedPhotoDate: DateTime.tryParse(
      j['reportedPhotoDate'] as String? ?? '',
    ),
    contentSha256: j['contentSha256'] as String? ?? '',
    pixelSha256: j['pixelSha256'] as String? ?? '',
    imageFingerprint: j['imageFingerprint'] as String? ?? '',
    duplicateOf: j['duplicateOf'] as String?,
    similarImageOf: j['similarImageOf'] as String?,
    specimenCode: j['specimenCode'] as String?,
    secondsAfterDipping: (j['secondsAfterDipping'] as num?)?.toDouble(),
    currentSpecimenConfirmed: j['currentSpecimenConfirmed'] == true,
    duplicateCheckCompleted: j['duplicateCheckCompleted'] == true,
  );
}
