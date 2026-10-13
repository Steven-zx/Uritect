import 'dart:async';
import 'support/load_app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/config/theme.dart';
import 'package:uritect_app/models/scan_analysis_failure.dart';
import 'package:uritect_app/models/scan_localization.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/pages/analyzing_page.dart';
import 'package:uritect_app/pages/results_page.dart';
import 'package:uritect_app/services/scan_analysis_service.dart';
import 'package:uritect_app/widgets/strip_analysis_animation.dart';

class PendingAnalysis extends ScanAnalysisService {
  final result = Completer<ScanResult>();
  void Function(ScanLocalization)? localization;
  void Function(double, String)? progress;
  @override
  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double, String)? onProgress,
    void Function(ScanLocalization)? onLocalization,
  }) {
    localization = onLocalization;
    progress = onProgress;
    return result.future;
  }
}

ScanLocalization fixture() {
  final photo = img.Image(width: 240, height: 600);
  img.fill(photo, color: img.ColorRgb8(242, 242, 235));
  img.fillRect(
    photo,
    x1: 105,
    y1: 25,
    x2: 132,
    y2: 575,
    color: img.ColorRgb8(255, 255, 255),
  );
  final labels = [
    'LEU',
    'NIT',
    'URO',
    'PRO',
    'pH',
    'BLD',
    'SG',
    'KET',
    'BIL',
    'GLU',
  ];
  final regions = <SampleRegion>[];
  for (var i = 0; i < 10; i++) {
    img.fillRect(
      photo,
      x1: 108,
      y1: 40 + i * 45,
      x2: 129,
      y2: 61 + i * 45,
      color: img.ColorRgb8(150 + i * 8, 185 - i * 8, 105 + i * 7),
    );
    regions.add(
      SampleRegion(
        labels[i],
        Rect.fromLTWH(108, (40 + i * 45).toDouble(), 22, 22),
      ),
    );
  }
  return ScanLocalization(
    preview: img.encodePng(photo),
    imageSize: const Size(240, 600),
    regions: regions,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await loadAppFonts();
  });
  testWidgets('progress reports real milestones without going backwards', (
    tester,
  ) async {
    final service = PendingAnalysis();
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyzingPage(
          imagePath: 'synthetic.jpg',
          analysisService: service,
        ),
      ),
    );
    service.progress!(25, 'checking_image_quality');
    await tester.pump();
    expect(find.text('Checking your photo'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    service.progress!(18, 'decoding_image');
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.result.complete(ScanResult.empty(imagePath: ''));
    await tester.pump();
  });
  test('photo containment maps exact coordinates without cropping', () {
    expect(
      containedPhotoRect(const Size(100, 400), const Size(300, 300)),
      const Rect.fromLTWH(112.5, 0, 75, 300),
    );
    expect(
      displayedSampleRect(
        const Rect.fromLTWH(20, 80, 10, 20),
        const Size(100, 400),
        const Size(300, 300),
      ),
      const Rect.fromLTWH(127.5, 60, 7.5, 15),
    );
    expect(
      displayedSampleRect(
        const Rect.fromLTWH(80, 20, 20, 10),
        const Size(400, 100),
        const Size(300, 300),
      ),
      const Rect.fromLTWH(60, 127.5, 15, 7.5),
    );
  });
  testWidgets(
    'timers never invent boxes; genuine geometry survives classification rejection',
    (tester) async {
      final service = PendingAnalysis();
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingPage(
            imagePath: 'synthetic.jpg',
            analysisService: service,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      expect(find.byKey(const ValueKey('actual-pad-overlay')), findsNothing);
      expect(find.byType(ResultsPage), findsNothing);
      service.localization!(fixture());
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('actual-pad-overlay')), findsOneWidget);
      expect(find.text('1 sampling region located'), findsOneWidget);
      for (var count = 2; count <= 10; count++) {
        await tester.pump(const Duration(milliseconds: 90));
        expect(find.text('$count sampling regions located'), findsOneWidget);
        final overlay =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('actual-pad-overlay')),
                    )
                    .painter!
                as SampleRegionPainter;
        expect(overlay.localization.regions.length, count);
      }
      expect(find.text('10 sampling regions located'), findsOneWidget);
      service.result.completeError(
        ScanAnalysisFailure(
          code: 'LOW_CONFIDENCE',
          guidance: 'Retake in even lighting.',
          padsDetected: 10,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResultsPage), findsOneWidget);
      expect(
        find.text('No readings available. Please take a new photo.'),
        findsOneWidget,
      );
      expect(find.text('View sampled pad regions'), findsOneWidget);
      expect(
        (tester.widget(find.byType(ResultsPage)) as ResultsPage)
            .scanResult
            .rows,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('small screen and reduced motion stay static and readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = PendingAnalysis();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.8),
          ),
          child: AnalyzingPage(
            imagePath: 'synthetic.jpg',
            analysisService: service,
          ),
        ),
      ),
    );
    service.localization!(fixture());
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.result.complete(ScanResult.empty(imagePath: ''));
    await tester.pump();
  });
  testWidgets(
    'fast analysis waits for the real measured boxes to be presented',
    (tester) async {
      final service = PendingAnalysis();
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingPage(
            imagePath: 'synthetic.jpg',
            analysisService: service,
          ),
        ),
      );
      service.localization!(fixture());
      service.result.complete(ScanResult.empty(imagePath: 'synthetic.jpg'));
      await tester.pump();
      expect(find.byType(ResultsPage), findsNothing);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ResultsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('animation pauses on background and disposes cleanly', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StripAnalysisAnimation(
              stage: 'classifying_pads',
              localization: fixture(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone visual reference for actual-photo overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = PendingAnalysis();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AnalyzingPage(
            imagePath: 'synthetic.jpg',
            analysisService: service,
          ),
        ),
      ),
    );
    final photo = fixture();
    service.localization!(photo);
    service.progress!(80, 'classifying_pads');
    await tester.pump();
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(photo.preview),
        tester.element(find.byType(StripAnalysisAnimation)),
      );
      await GoogleFonts.pendingFonts();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/strip_analysis_photo_overlay.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    service.result.complete(ScanResult.empty(imagePath: ''));
    await tester.pump();
  });
}
