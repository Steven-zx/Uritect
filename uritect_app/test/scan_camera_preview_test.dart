import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/widgets/scan_camera_preview.dart';
import 'package:uritect_app/widgets/ten_pad_alignment_guide.dart';

void main() {
  for (final orientation in [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
  ]) {
    testWidgets('cover frame and focus mapping for $orientation', (
      tester,
    ) async {
      final controller = CameraController(
        const CameraDescription(
          name: 'rear',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.max,
      );
      controller.value = controller.value.copyWith(
        isInitialized: true,
        previewSize: const Size(1280, 720),
        deviceOrientation: orientation,
      );
      Offset? focused;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: ScanCameraPreview(
                controller: controller,
                onFocus: (point) => focused = point,
                showAlignmentGuide: true,
              ),
            ),
          ),
        ),
      );
      final viewport = tester.getRect(find.byType(ScanCameraPreview));
      final image = tester.getRect(find.byType(CameraPreview));
      expect(image.left, lessThanOrEqualTo(viewport.left));
      expect(image.top, lessThanOrEqualTo(viewport.top));
      expect(image.right, greaterThanOrEqualTo(viewport.right));
      expect(image.bottom, greaterThanOrEqualTo(viewport.bottom));
      final expectedRatio = orientation == DeviceOrientation.portraitUp
          ? 720 / 1280
          : 1280 / 720;
      expect(image.width / image.height, closeTo(expectedRatio, 0.001));
      final tap =
          viewport.topLeft +
          Offset(viewport.width * .25, viewport.height * .75);
      await tester.tapAt(tap);
      expect(focused!.dx, closeTo((tap.dx - image.left) / image.width, .001));
      expect(focused!.dy, closeTo((tap.dy - image.top) / image.height, .001));
      // Tapping an outlined pad must still focus at the real image coordinate.
      for (var i = 0; i < 10; i++) {
        final rect = tester.getRect(find.byKey(ValueKey('alignment-pad-$i')));
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
        await tester.tapAt(rect.center);
        expect(
          focused!.dx,
          closeTo((rect.center.dx - image.left) / image.width, .001),
        );
        expect(
          focused!.dy,
          closeTo((rect.center.dy - image.top) / image.height, .001),
        );
      }
      expect(find.byType(TenPadAlignmentGuide), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.dispose();
    });
  }
}
