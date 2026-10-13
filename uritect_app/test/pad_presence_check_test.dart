import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/pad_presence_check.dart';

void main() {
  test('a lighting gradient alone cannot become a pad', () {
    final image = img.Image(width: 260, height: 140);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final value = 80 + x ~/ 2;
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    expect(
      PadPresenceCheck.isSupported(
        image,
        left: 100,
        top: 50,
        width: 20,
        height: 20,
      ),
      isFalse,
    );
    expect(
      PadPresenceCheck.hasPersistentStripEdge(
        image,
        left: 100,
        top: 50,
        width: 20,
        height: 20,
      ),
      isFalse,
    );
    img.fillRect(
      image,
      x1: 95,
      y1: 45,
      x2: 125,
      y2: 75,
      color: img.ColorRgb8(30, 170, 220),
    );
    expect(
      PadPresenceCheck.isSupported(
        image,
        left: 100,
        top: 50,
        width: 20,
        height: 20,
      ),
      isTrue,
    );
  });
  test(
    'a marker on one side cannot manufacture pad presence on a uniform background',
    () {
      final image = img.Image(width: 260, height: 140);
      img.fill(image, color: img.ColorRgb8(180, 180, 180));
      img.fillRect(
        image,
        x1: 20,
        y1: 45,
        x2: 60,
        y2: 75,
        color: img.ColorRgb8(0, 0, 0),
      );
      expect(
        PadPresenceCheck.isSupported(
          image,
          left: 100,
          top: 50,
          width: 20,
          height: 20,
        ),
        isFalse,
      );
    },
  );
  test('out-of-frame boxes fail closed', () {
    final image = img.Image(width: 20, height: 20);
    expect(
      PadPresenceCheck.isSupported(
        image,
        left: 18,
        top: 0,
        width: 20,
        height: 10,
      ),
      isFalse,
    );
  });
}
