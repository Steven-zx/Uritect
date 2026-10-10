import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/runtime_pad_features.dart';

void main() {
  test(
    'Python and actual runtime feature math agree on identical pixels and gains',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/runtime_pad_color_parity.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final raw = <String, List<double>>{};
      for (final entry in fixture['cases'] as List) {
        final image = img.decodePng(
          base64Decode(entry['png_base64'] as String),
        )!;
        final roi = entry['roi'] as List;
        final value = RuntimePadFeatures.meanHsv(
          image,
          left: roi[0],
          top: roi[1],
          width: roi[2],
          height: roi[3],
          rgbGains: (entry['gains_rgb'] as List)
              .map((v) => (v as num).toDouble())
              .toList(),
        );
        final expected = (entry['expected_hsv'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        final hueDifference = ((value[0] - expected[0] + 180) % 360 - 180)
            .abs();
        expect(
          hueDifference,
          lessThan(1e-9),
          reason: 'hue case ${entry['id']}',
        );
        expect(value[1], closeTo(expected[1], 1e-12));
        expect(value[2], closeTo(expected[2], 1e-12));
        if (entry['id'] < 10) raw['${entry['id']}'] = value;
      }
      final normalized = RuntimePadFeatures.normalizeHsv(raw).values.toList();
      final expected = fixture['normalized_first_ten'] as List;
      for (var i = 0; i < 10; i++) {
        expect(
          ((normalized[i][0] - expected[i][0] + 180) % 360 - 180).abs(),
          lessThan(1e-9),
        );
        expect(normalized[i][1], closeTo(expected[i][1], 1e-12));
        expect(normalized[i][2], closeTo(expected[i][2], 1e-12));
      }
    },
  );

  test('circular averaging preserves red near hue zero', () {
    final image = img.Image(width: 20, height: 20);
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, 255, x.isEven ? 4 : 0, x.isEven ? 0 : 4);
      }
    }
    final hsv = RuntimePadFeatures.meanHsv(
      image,
      left: 0,
      top: 0,
      width: 20,
      height: 20,
      rgbGains: [1, 1, 1],
    );
    expect(hsv[0] < 2 || hsv[0] > 358, isTrue);
  });
}
