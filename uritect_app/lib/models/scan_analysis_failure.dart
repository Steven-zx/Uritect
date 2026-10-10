/// A rejected scan is not necessarily a failure to find reagent pads.
/// Keep the measured localization count separate from interpretation failure.
class ScanAnalysisFailure extends StateError {
  final String code;
  final String guidance;
  final int? padsDetected;

  ScanAnalysisFailure({
    required this.code,
    required this.guidance,
    this.padsDetected,
  }) : super(
         code == 'LOW_CONFIDENCE'
             ? '$code: $guidance'
             : 'INVALID_IMAGE: $code: $guidance',
       );

  factory ScanAnalysisFailure.fromError(Object error) {
    if (error is ScanAnalysisFailure) return error;
    final text = error.toString().toLowerCase();
    final (code, guidance) = switch (text) {
      _ when text.contains('too dark') => (
        'IMAGE_TOO_DARK',
        'The image is too dark. Use even lighting and retake the photo.',
      ),
      _ when text.contains('overexposed') => (
        'IMAGE_OVEREXPOSED',
        'The image is overexposed. Reduce glare and retake the photo.',
      ),
      _ when text.contains('blurred') => (
        'IMAGE_BLURRED',
        'The image is blurred. Tap the strip to focus and hold the phone steady.',
      ),
      _ when text.contains('low_confidence') => (
        'LOW_CONFIDENCE',
        'The pad colors could not be classified confidently. Retake under even lighting.',
      ),
      _ => (
        'STRIP_NOT_CONFIRMED',
        'A complete ten-pad strip could not be confirmed. Keep the whole strip large, upright, and in focus on a plain background.',
      ),
    };
    // An unstructured error does not establish a measured pad count.
    return ScanAnalysisFailure(code: code, guidance: guidance);
  }
}
