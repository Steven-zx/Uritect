import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:uritect_app/services/scan_provenance_service.dart';
import 'package:uritect_app/services/history_cipher.dart';
import 'package:uritect_app/services/scan_history_service.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/models/saved_scan_record.dart';
import 'package:uritect_app/pages/home_page.dart';
import 'package:uritect_app/pages/protected_history_page.dart';
import 'package:uritect_app/pages/performance_notes_page.dart';
import 'package:uritect_app/pages/overall_results_page.dart';
import 'package:uritect_app/pages/renal_results_page.dart';
import 'strict_scan_reliability_test.dart' as fixture;
import 'protected_history_storage_test.dart' show TestCipher;

class UiHistoryService extends ScanHistoryService {
  SavedScanRecord record;
  UiHistoryService(this.record);
  @override
  Future<List<SavedScanRecord>> loadRecords() async {
    await authenticate();
    return [record];
  }

  @override
  Future<SavedScanRecord> updatePatientName(String id, String? name) async {
    await authenticate();
    record = record.withPatientName(name);
    return record;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'canonical pixel hash detects the same photo in different lossless containers',
    () async {
      final dir = await Directory.systemTemp.createTemp('uritect_identity_');
      try {
        final image = img.Image(width: 19, height: 21);
        for (final pixel in image) {
          pixel.setRgb((pixel.x * 13) % 256, (pixel.y * 17) % 256, 60);
        }
        final a = File('${dir.path}/a.png');
        final b = File('${dir.path}/b.bmp');
        await a.writeAsBytes(img.encodePng(image));
        await b.writeAsBytes(img.encodeBmp(image));
        final first = await const ScanProvenanceService().inspect(a.path);
        final second = await const ScanProvenanceService().inspect(b.path);
        expect(first.contentHash, isNot(second.contentHash));
        expect(first.pixelHash, second.pixelHash);
        expect(first.fingerprint, second.fingerprint);
        expect(
          first.reportedPhotoDate,
          isNull,
          reason:
              'Filesystem modification time is not asserted as capture time.',
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  late Directory root;
  late TestCipher cipher;
  bool allow = true;
  int authCalls = 0;
  final privacy = <bool>[];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('uritect_history_ui_');
    cipher = TestCipher();
    allow = true;
    authCalls = 0;
    privacy.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformHistoryCipher.channel, (call) async {
          switch (call.method) {
            case 'authenticate':
              authCalls++;
              return {'authenticated': allow, 'remainingMillis': 120000};
            case 'privacy':
              privacy.add((call.arguments as Map)['enabled'] as bool);
              return null;
            case 'lock':
              return null;
            case 'encrypt':
              return cipher.encrypt(
                (call.arguments as Map)['bytes'] as Uint8List,
                (call.arguments as Map)['context'] as String,
              );
            case 'decrypt':
              return cipher.decrypt(
                (call.arguments as Map)['bytes'] as Uint8List,
                (call.arguments as Map)['context'] as String,
              );
            default:
              throw StateError(call.method);
          }
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformHistoryCipher.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });
  UiHistoryService seed() {
    final scan = fixture.scan();
    final checklist = ClinicalChecklistResult(selectedSymptoms: const {});
    return UiHistoryService(
      SavedScanRecord.fromAnalysis(
        scanResult: scan,
        checklistResult: checklist,
        fusionResult: const ScreeningFusionEngine().fuse(
          analytes: const [],
          checklist: checklist,
          scanResult: scan,
        ),
        renalFollowupResult: const RenalFollowupEngine().evaluate(
          scanResult: scan,
          checklist: checklist,
        ),
      ),
    );
  }

  testWidgets(
    'history remains locked until authentication and hides after expiry',
    (tester) async {
      final history = seed();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedHistoryPage(recordId: 'test', historyService: history),
        ),
      );
      await tester.pumpAndSettle();
      expect(authCalls, 2);
      expect(find.byType(OverallResultsPage), findsOneWidget);
      expect(privacy.last, isTrue);
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(find.text('History is locked.'), findsOneWidget);
      expect(find.byType(OverallResultsPage), findsNothing);
    },
  );
  testWidgets(
    'patient name can be saved and is hidden when history backgrounds',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final history = seed();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedHistoryPage(
            recordId: 'test',
            editNameInitially: true,
            historyService: history,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('patient_name_input')),
        'Test Patient',
      );
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(history.record.patientName, 'Test Patient');
      expect(find.text('Test Patient'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Edit patient name'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('patient_name_input')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('patient_name_input')), findsNothing);
      expect(find.text('Test Patient'), findsNothing);
      expect(find.text('History is locked.'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'history cancellation stays locked; home does not auto-read records',
    (tester) async {
      allow = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pumpAndSettle();
      expect(authCalls, 0);
      expect(find.text('Unlock saved history'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: ProtectedHistoryPage(recordId: 'test')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Authentication was cancelled'),
        findsOneWidget,
      );
      expect(find.text('Overall Results'), findsNothing);
    },
  );
  testWidgets('child renal history view is also locked on backgrounding', (
    tester,
  ) async {
    final history = seed();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: ProtectedHistoryPage(recordId: 'test', historyService: history),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('View renal follow-up details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View renal follow-up details'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byType(ProtectedHistoryPage), findsOneWidget);
    expect(find.byType(RenalResultsPage), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('History is locked.'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('History is locked.'), findsOneWidget);
  });
  testWidgets(
    'optional research details remain protected when history backgrounds',
    (tester) async {
      final history = seed();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: ProtectedHistoryPage(recordId: 'test', historyService: history),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Research Details'));
      await tester.tap(find.text('Research Details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Classifier:'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('History is locked.'), findsOneWidget);
      expect(find.textContaining('Classifier:'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'performance page separates historical metrics and clinical limits',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PerformanceNotesPage()));
      expect(find.textContaining('82.52% individual-analyte'), findsOneWidget);
      expect(find.textContaining('17.18% all-ten'), findsOneWidget);
      expect(find.textContaining('19.17% all-ten'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(find.textContaining('culture-confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
