import 'dart:typed_data';
import 'dart:ui';

/// Transient detector evidence. Never serialized into saved patient records.
class ScanLocalization {
  final Uint8List preview;
  final Size imageSize;
  final String orientation;
  final List<SampleRegion> regions;

  const ScanLocalization({
    required this.preview,
    required this.imageSize,
    required this.regions,
    this.orientation = 'exif',
  });

  factory ScanLocalization.fromMessage(Map message) => ScanLocalization(
    preview: message['preview'] as Uint8List,
    orientation: message['orientation'] as String? ?? 'exif',
    imageSize: Size(
      (message['width'] as num).toDouble(),
      (message['height'] as num).toDouble(),
    ),
    regions: List.unmodifiable([
      for (final region in message['regions'] as List)
        SampleRegion(
          region['label'] as String,
          Rect.fromLTWH(
            (region['left'] as num).toDouble(),
            (region['top'] as num).toDouble(),
            (region['width'] as num).toDouble(),
            (region['height'] as num).toDouble(),
          ),
        ),
    ]),
  );
}

class SampleRegion {
  final String label;
  final Rect rect;
  const SampleRegion(this.label, this.rect);
}

/// Shared by the photo and overlay: centered BoxFit.contain, without cropping.
Rect containedPhotoRect(Size image, Size viewport) {
  final scale =
      (viewport.width / image.width) < (viewport.height / image.height)
      ? viewport.width / image.width
      : viewport.height / image.height;
  final size = Size(image.width * scale, image.height * scale);
  return Rect.fromLTWH(
    (viewport.width - size.width) / 2,
    (viewport.height - size.height) / 2,
    size.width,
    size.height,
  );
}

Rect displayedSampleRect(Rect sample, Size image, Size viewport) {
  final photo = containedPhotoRect(image, viewport);
  final scale = photo.width / image.width;
  return Rect.fromLTWH(
    photo.left + sample.left * scale,
    photo.top + sample.top * scale,
    sample.width * scale,
    sample.height * scale,
  );
}
