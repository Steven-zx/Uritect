import 'dart:typed_data';

class WhiteReferenceRegion {
  const WhiteReferenceRegion({
    required this.xNorm,
    required this.yNorm,
    required this.widthNorm,
    required this.heightNorm,
  });

  final double xNorm;
  final double yNorm;
  final double widthNorm;
  final double heightNorm;

  WhiteReferenceRegion normalized() {
    final x = xNorm.clamp(0.0, 1.0);
    final y = yNorm.clamp(0.0, 1.0);
    final width = widthNorm.clamp(0.0, 1.0 - x);
    final height = heightNorm.clamp(0.0, 1.0 - y);

    return WhiteReferenceRegion(
      xNorm: x,
      yNorm: y,
      widthNorm: width,
      heightNorm: height,
    );
  }
}

class AwbResult {
  const AwbResult({
    required this.correctedBytes,
    required this.gainR,
    required this.gainG,
    required this.gainB,
    required this.referenceMeanR,
    required this.referenceMeanG,
    required this.referenceMeanB,
  });

  final Uint8List correctedBytes;
  final double gainR;
  final double gainG;
  final double gainB;
  final double referenceMeanR;
  final double referenceMeanG;
  final double referenceMeanB;
}
