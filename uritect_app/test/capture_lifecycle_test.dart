import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/pages/capture_dipstick_page.dart';
import 'package:uritect_app/widgets/ten_pad_alignment_guide.dart';

class FakeCamera extends CameraPlatform {
  int created = 0;
  final active = <int>{};
  final disposed = <int>[];
  int maxActive = 0;
  int captures = 0;
  Completer<XFile>? pendingCapture;
  Completer<void>? pendingInitialization;
  final events = <int, StreamController<CameraInitializedEvent>>{};
  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'rear',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    final id = ++created;
    active.add(id);
    maxActive = max(maxActive, active.length);
    events[id] = StreamController<CameraInitializedEvent>.broadcast();
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) =>
      events[id]!.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (pendingInitialization != null) await pendingInitialization!.future;
    events[id]!.add(
      CameraInitializedEvent(
        id,
        1080,
        1920,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Future<void> dispose(int id) async {
    active.remove(id);
    disposed.add(id);
    await events[id]?.close();
  }

  @override
  Widget buildPreview(int id) => Text('camera preview $id');
  @override
  Future<void> setFocusMode(int id, FocusMode mode) async {}
  @override
  Future<void> setExposureMode(int id, ExposureMode mode) async {}
  @override
  Future<void> setFocusPoint(int id, Point<double>? point) async {}
  @override
  Future<void> setExposurePoint(int id, Point<double>? point) async {}
  @override
  Future<void> setFlashMode(int id, FlashMode mode) async {}
  @override
  Future<XFile> takePicture(int id) {
    captures++;
    return pendingCapture!.future;
  }
}

void main() {
  late CameraPlatform original;
  late FakeCamera fake;
  setUp(() {
    original = CameraPlatform.instance;
    fake = FakeCamera();
    CameraPlatform.instance = fake;
  });
  tearDown(() {
    CameraPlatform.instance = original;
  });
  Future<void> open(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: CaptureDipstickPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('ten-pad guide toggles without restarting the camera', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(TenPadAlignmentGuide), findsNothing);
    await tester.tap(find.byTooltip('Show 10-pad guide'));
    await tester.pumpAndSettle();
    expect(find.byType(TenPadAlignmentGuide), findsOneWidget);
    expect(fake.created, 1);
    await tester.tap(find.byTooltip('Hide 10-pad guide'));
    await tester.pumpAndSettle();
    expect(find.byType(TenPadAlignmentGuide), findsNothing);
    expect(fake.created, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera is released on background and reopened on resume', (
    tester,
  ) async {
    await open(tester);
    expect(fake.created, 1);
    expect(fake.active.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(fake.active, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.created, 2);
    expect(fake.active.length, 1);
    expect(fake.maxActive, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(fake.active, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid pause/resume never opens simultaneous cameras', (
    tester,
  ) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.active.length, 1);
    expect(fake.maxActive, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('late initialization cannot update a removed capture page', (
    tester,
  ) async {
    fake.pendingInitialization = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: CaptureDipstickPage()));
    await tester.pump();
    expect(fake.created, 1);
    await tester.pumpWidget(const SizedBox());
    fake.pendingInitialization!.complete();
    await tester.pumpAndSettle();
    expect(fake.active, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'capture finishing after background cannot restore a stale photo',
    (tester) async {
      late Directory dir;
      late File photo;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('uritect_stale_');
        photo = File('${dir.path}/stale.png');
        await photo.writeAsBytes(
          img.encodePng(img.Image(width: 30, height: 30)),
        );
      });
      fake.pendingCapture = Completer<XFile>();
      await open(tester);
      await tester.tap(find.byKey(const Key('capture_shutter')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      fake.pendingCapture!.complete(XFile(photo.path));
      await tester.pumpAndSettle();
      expect(find.text('SUBMIT'), findsNothing);
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => dir.delete(recursive: true));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'double shutter does not duplicate capture and retake clears the old photo',
    (tester) async {
      late Directory dir;
      late File photo;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('uritect_camera_test_');
        photo = File('${dir.path}/camera.png');
        await photo.writeAsBytes(
          img.encodePng(img.Image(width: 30, height: 30)),
        );
      });
      fake.pendingCapture = Completer<XFile>();
      await open(tester);
      await tester.tap(find.byTooltip('Show 10-pad guide'));
      await tester.pumpAndSettle();
      final shutter = find.byKey(const Key('capture_shutter'));
      await tester.tap(shutter);
      await tester.tap(shutter);
      await tester.pump();
      expect(fake.captures, 1);
      fake.pendingCapture!.complete(XFile(photo.path));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('SUBMIT'), findsOneWidget);
      expect(find.byType(TenPadAlignmentGuide), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.grid_off_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(shutter);
      await tester.pumpAndSettle();
      expect(find.text('SUBMIT'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(TenPadAlignmentGuide), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => dir.delete(recursive: true));
      expect(tester.takeException(), isNull);
    },
  );
}
