import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/saved_scan_record.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/services/history_cipher.dart';
import 'package:uritect_app/services/scan_history_service.dart';
import 'strict_scan_reliability_test.dart' as fixture;

/// Authenticated test transport, deliberately not the native production cipher.
/// These tests exercise persistence/recovery; AndroidKeyStore needs device tests.
class TestCipher implements HistoryCipher {
  bool cancelled = false;
  bool unavailable = false;
  int? failEncryption;
  int count = 0;
  @override
  Duration get remainingSession => const Duration(minutes: 2);
  @override
  Future<void> authenticate() async {
    if (cancelled) throw StateError('Cancelled');
  }

  @override
  Future<void> lock() async {}
  @override
  Future<Uint8List> encrypt(Uint8List data, String context) async {
    if (++count == failEncryption) {
      throw PlatformException(code: 'HISTORY_KEY_UNAVAILABLE');
    }
    final body = data.map((b) => b ^ 91).toList();
    final tag = Hmac(
      sha256,
      utf8.encode('test-key:$context'),
    ).convert(body).bytes;
    return Uint8List.fromList([...tag, ...body]);
  }

  @override
  Future<Uint8List> decrypt(Uint8List data, String context) async {
    if (unavailable) throw PlatformException(code: 'HISTORY_KEY_UNAVAILABLE');
    if (data.length < 32 ||
        base64Encode(data.sublist(0, 32)) !=
            base64Encode(
              Hmac(
                sha256,
                utf8.encode('test-key:$context'),
              ).convert(data.sublist(32)).bytes,
            )) {
      throw PlatformException(code: 'HISTORY_INTEGRITY_ERROR');
    }
    return Uint8List.fromList(data.sublist(32).map((b) => b ^ 91).toList());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late TestCipher cipher;
  late ScanHistoryService service;
  File file(String name) => File('${dir.path}/$name');
  Future<SavedScanRecord> save(String id, {String imagePath = ''}) async {
    final scan = fixture.scan().copyWith(id: id, imagePath: imagePath);
    final checklist = ClinicalChecklistResult(selectedSymptoms: const {});
    final fusion = const ScreeningFusionEngine().fuse(
      analytes: [
        for (final row in scan.rows)
          ScreeningAnalyteResult(
            code: row.code,
            name: row.name,
            displayValue: row.result,
          ),
      ],
      checklist: checklist,
      scanResult: scan,
    );
    final renal = const RenalFollowupEngine().evaluate(
      scanResult: scan,
      checklist: checklist,
    );
    return service.saveCompletedScan(
      scanResult: scan,
      checklistResult: checklist,
      fusionResult: fusion,
      renalFollowupResult: renal,
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('uritect_history_');
    cipher = TestCipher();
    service = ScanHistoryService(
      cipher: cipher,
      directoryProvider: () => Future.value(dir),
    );
    ScanHistoryService.recoveryNotice = null;
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
    'patient name edits preserve the scan and use protected atomic storage',
    () async {
      await save('named');
      final original = (await service.loadRecords()).single;
      final updated = await service.updatePatientName(
        'named',
        '  Test Patient  ',
      );
      expect(updated.patientName, 'Test Patient');
      final unchanged = updated.toJson()..['patientName'] = null;
      expect(unchanged, original.toJson());
      expect((await service.loadRecords()).single.patientName, 'Test Patient');
      final disk = await file('history.v2.enc').readAsBytes();
      expect(
        utf8.decode(disk, allowMalformed: true),
        isNot(contains('Test Patient')),
      );
      expect(await file('history.json').exists(), isFalse);
      expect(
        (await service.updatePatientName('named', '')).patientName,
        isNull,
      );
      expect((await service.loadRecords()).single.patientName, isNull);
    },
  );
  test(
    'missing and invalid patient-name edits leave existing history intact',
    () async {
      await save('existing');
      final original = (await service.loadRecords()).single;
      await expectLater(
        service.updatePatientName('missing', 'Test'),
        throwsStateError,
      );
      await expectLater(
        service.updatePatientName('existing', 'Line\nBreak'),
        throwsArgumentError,
      );
      expect((await service.loadRecords()).single.toJson(), original.toJson());
      final legacy = original.toJson()..remove('patientName');
      expect(SavedScanRecord.fromJson(legacy).patientName, isNull);
    },
  );
  test(
    'concurrent saves are serialized; protected index and images round trip',
    () async {
      final photo = file('photo.jpg');
      await photo.writeAsBytes([1, 2, 3, 4]);
      final results = await Future.wait([
        save('one', imagePath: photo.path),
        save('two'),
      ]);
      expect((await service.loadRecords()).map((r) => r.id).toSet(), {
        'one',
        'two',
      });
      expect(await service.readImage(results.first.scanResult.imagePath), [
        1,
        2,
        3,
        4,
      ]);
      expect(await file('history.json').exists(), isFalse);
      expect(
        utf8.decode(
          await file('history.v2.enc').readAsBytes(),
          allowMalformed: true,
        ),
        isNot(contains('selectedSymptoms')),
      );
      expect(
        await photo.exists(),
        isTrue,
        reason: 'External/original photos are not deleted by saving.',
      );
    },
  );
  test('corrupt primary recovers previous copy with visible notice', () async {
    await save('one');
    await save('two');
    await file('history.v2.enc').writeAsString('damaged');
    expect((await service.loadRecords()).map((r) => r.id), ['one']);
    expect(
      ScanHistoryService.recoveryNotice,
      contains('Recent changes may be missing'),
    );
    expect(await dir.list().any((f) => f.path.contains('.corrupt.')), isTrue);
  });
  test('both corrupt indexes block save and preserve original bytes', () async {
    await save('one');
    await file('history.v2.enc').writeAsString('primary-bad');
    await file('history.recovery.enc').writeAsString('backup-bad');
    await expectLater(
      service.loadRecords(),
      throwsA(isA<HistoryCorruptionException>()),
    );
    await expectLater(save('new'), throwsA(isA<HistoryCorruptionException>()));
    expect(await file('history.v2.enc').readAsString(), 'primary-bad');
    expect(await file('history.recovery.enc').readAsString(), 'backup-bad');
  });
  test(
    'access/key failures are not treated as corruption or empty history',
    () async {
      await save('one');
      final original = await file('history.v2.enc').readAsBytes();
      cipher.unavailable = true;
      await expectLater(
        service.loadRecords(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'HISTORY_KEY_UNAVAILABLE',
          ),
        ),
      );
      expect(await file('history.v2.enc').readAsBytes(), original);
      expect(ScanHistoryService.recoveryNotice, isNull);
      cipher.unavailable = false;
      cipher.cancelled = true;
      await expectLater(save('two'), throwsStateError);
      cipher.cancelled = false;
      expect((await service.loadRecords()).length, 1);
    },
  );
  test(
    'deletion journal prevents recovery from resurrecting deleted record',
    () async {
      await save('one');
      await save('two');
      expect(await service.deleteRecord('one'), isTrue);
      await file('history.v2.enc').writeAsString('damaged');
      expect((await service.loadRecords()).map((r) => r.id), ['two']);
      await expectLater(save('one'), throwsStateError);
      await file('deleted.v2.enc').writeAsString('damaged');
      await expectLater(
        service.loadRecords(),
        throwsA(isA<HistoryCorruptionException>()),
      );
    },
  );
  test(
    'valid interrupted first-save staging is recovered; invalid staging blocks overwrite',
    () async {
      await save('one');
      await file('history.recovery.enc').delete();
      await file('history.v2.enc').rename(file('history.v2.enc.tmp').path);
      expect((await service.loadRecords()).single.id, 'one');
      expect(
        ScanHistoryService.recoveryNotice,
        contains('interrupted first save'),
      );
      await file('history.v2.enc').delete();
      await file('history.recovery.enc').delete();
      await file('history.v2.enc.tmp').writeAsString('bad');
      await expectLater(
        save('two'),
        throwsA(isA<HistoryCorruptionException>()),
      );
      expect(await file('history.v2.enc.tmp').readAsString(), 'bad');
    },
  );
  test(
    'legacy migration preserves results and encrypts photo before removing private plaintext',
    () async {
      final oldScan = fixture.scan().toJson()
        ..remove('provenance')
        ..remove('supportCheckPassed')
        ..remove('nearestTrainingDistances');
      final photo = file('old.jpg');
      await photo.writeAsBytes([9, 8, 7]);
      oldScan['imagePath'] = photo.path;
      final old = SavedScanRecord(
        id: 'test',
        savedAt: DateTime(2026, 10, 1),
        scanResult: ScanResult.fromJson(oldScan),
        checklistResult: ClinicalChecklistResult(
          selectedSymptoms: const {'dysuria': true},
        ),
        clinicalAction: 'Consultation suggested',
        utiPosteriorProbability: .72,
        utiCalculationStatus: 'calculated',
      );
      await file('history.json').writeAsString(jsonEncode([old.toJson()]));
      cipher.failEncryption = 2;
      await expectLater(
        service.loadRecords(),
        throwsA(isA<PlatformException>()),
      );
      expect(await file('history.json').exists(), isTrue);
      expect(await photo.exists(), isTrue);
      cipher.failEncryption = null;
      final migrated = (await service.loadRecords()).single;
      expect(migrated.utiPosteriorProbability, .72);
      expect(migrated.scanResult.isLegacyUnverified, isTrue);
      expect(migrated.savedAt, old.savedAt);
      expect(await service.readImage(migrated.scanResult.imagePath), [9, 8, 7]);
      expect(await file('history.json').exists(), isFalse);
      expect(await photo.exists(), isFalse);
      // Simulate interruption after protected commit but before legacy cleanup.
      await photo.writeAsBytes([9, 8, 7]);
      await file('history.json').writeAsString(jsonEncode([old.toJson()]));
      expect((await service.loadRecords()).single.id, 'test');
      expect(await file('history.json').exists(), isFalse);
      expect(await photo.exists(), isFalse);
    },
  );
  test(
    'malformed legacy records and out-of-directory photos fail closed',
    () async {
      await file('history.json').writeAsString('[broken');
      await expectLater(
        save('new'),
        throwsA(isA<HistoryCorruptionException>()),
      );
      expect(await file('history.json').readAsString(), '[broken');
      final outside = await Directory.systemTemp.createTemp(
        'uritect_external_',
      );
      try {
        final photo = File('${outside.path}/x.jpg');
        await photo.writeAsBytes([1]);
        final old = SavedScanRecord(
          id: 'test',
          savedAt: DateTime(2026, 10, 1),
          scanResult: fixture.scan().copyWith(imagePath: photo.path),
          checklistResult: ClinicalChecklistResult(selectedSymptoms: const {}),
          clinicalAction: 'archive',
        );
        await file('history.json').writeAsString(jsonEncode([old.toJson()]));
        await expectLater(
          service.loadRecords(),
          throwsA(isA<HistoryCorruptionException>()),
        );
        expect(await photo.exists(), isTrue);
        await expectLater(
          service.readImage(
            '${dir.path}/../${outside.uri.pathSegments.where((s) => s.isNotEmpty).last}/x.jpg',
          ),
          throwsStateError,
        );
      } finally {
        await outside.delete(recursive: true);
      }
    },
  );
  test(
    'image tampering is detected; exact and similar matches stay distinct',
    () async {
      final photo = file('p.jpg');
      await photo.writeAsBytes([1, 2]);
      final record = await save('one', imagePath: photo.path);
      final p = record.scanResult.provenance!;
      expect(
        (await service.findDuplicate(
          contentSha256: p.contentSha256,
          pixelSha256: 'different',
          fingerprint: 'different',
        ))!.exact,
        isTrue,
      );
      expect(
        (await service.findDuplicate(
          contentSha256: 'different',
          pixelSha256: p.pixelSha256,
          fingerprint: 'different',
        ))!.exact,
        isTrue,
      );
      expect(
        (await service.findDuplicate(
          contentSha256: 'different',
          pixelSha256: 'different',
          fingerprint: p.imageFingerprint,
        ))!.exact,
        isFalse,
      );
      await File(record.scanResult.imagePath).writeAsString('tampered');
      await expectLater(
        service.readImage(record.scanResult.imagePath),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
