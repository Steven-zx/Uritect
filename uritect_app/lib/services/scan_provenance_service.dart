import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class ImageIdentity {
  final String contentHash;
  final String pixelHash;
  final String fingerprint;
  final DateTime? reportedPhotoDate;
  const ImageIdentity(
    this.contentHash,
    this.pixelHash,
    this.fingerprint,
    this.reportedPhotoDate,
  );
}

class ScanProvenanceService {
  const ScanProvenanceService();
  Future<ImageIdentity> inspect(String path) => Isolate.run(() {
    final bytes = File(path).readAsBytesSync();
    final hash = sha256.convert(bytes).toString();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return ImageIdentity(hash, hash, hash, null);
    final rawDate = decoded.exif.exifIfd[0x9003]?.toString() ?? '';
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(rawDate);
    final date = match == null
        ? null
        : DateTime.tryParse(
            '${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}',
          );
    final oriented = img.bakeOrientation(decoded);
    // Strip EXIF and container differences before hashing identical decoded pixels.
    final pixels = oriented.getBytes(order: img.ChannelOrder.rgb);
    final buffer = BytesBuilder(copy: false)
      ..add([
        ...oriented.width.toString().codeUnits,
        0,
        ...oriented.height.toString().codeUnits,
        0,
      ])
      ..add(pixels);
    final pixelHash = sha256.convert(buffer.takeBytes()).toString();
    final small = img.copyResize(
      oriented,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );
    var bits = BigInt.zero;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final a = small.getPixel(x, y);
        final b = small.getPixel(x + 1, y);
        final left = .299 * a.r + .587 * a.g + .114 * a.b;
        final right = .299 * b.r + .587 * b.g + .114 * b.b;
        bits = (bits << 1) | (left > right ? BigInt.one : BigInt.zero);
      }
    }
    // Equality is a similarity warning, never proof of specimen identity.
    return ImageIdentity(
      hash,
      pixelHash,
      bits.toRadixString(16).padLeft(16, '0'),
      date,
    );
  });
}
