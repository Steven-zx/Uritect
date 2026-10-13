import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/clinical_symptoms.dart';
import 'package:uritect_app/models/scan_model.dart';
import 'package:uritect_app/models/renal_followup.dart';
import 'package:uritect_app/models/screening_fusion.dart';
import 'package:uritect_app/services/pending_scan_cipher.dart';
import 'package:uritect_app/services/scan_history_service.dart';
import 'protected_history_storage_test.dart' show TestCipher;
import 'provisional_readings_test.dart' as fixture;

class CountingCipher extends TestCipher {
  int prompts = 0;
  bool unlocked = false;
  @override
  Future<void> authenticate() async {
    prompts++;
    await super.authenticate();
    unlocked = true;
  }

  @override
  Future<void> lock() async {
    unlocked = false;
  }
}

// Host test transport only; production uses Android Keystore RSA + AES-GCM.
class PendingTransport implements PendingScanCipher {
  final CountingCipher history;
  final TestCipher transport = TestCipher();
  PendingTransport(this.history);
  int seals = 0, opens = 0;
  @override
  Future<Uint8List> seal(Uint8List b, String c, bool existing) async {
    seals++;
    return transport.encrypt(b, c);
  }

  @override
  Future<Uint8List> open(Uint8List b, String c) async {
    if (!history.unlocked) throw PlatformException(code: 'HISTORY_LOCKED');
    opens++;
    return transport.decrypt(b, c);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory d;
  late CountingCipher cipher;
  late PendingTransport pending;
  late ScanHistoryService service;
  Future<void> queue({
    ClinicalChecklistResult? checklist,
    ScanResult? scan,
  }) async {
    final s = scan ?? fixture.baseScan();
    final c = checklist ?? fixture.checklist();
    await service.queueCompletedScan(
      scanResult: s,
      checklistResult: c,
      fusionResult: const ScreeningFusionEngine().fuse(
        scanResult: s,
        analytes: ScreeningFusionEngine.buildAnalytesFromRows(s.rows),
        checklist: c,
      ),
      renalFollowupResult: const RenalFollowupEngine().evaluate(
        scanResult: s,
        checklist: c,
      ),
    );
  }

  Future<File> envelope() async =>
      (await Directory('${d.path}/pending').list().toList()).single as File;
  setUp(() async {
    d = await Directory.systemTemp.createTemp('uritect_pending_');
    cipher = CountingCipher();
    pending = PendingTransport(cipher);
    service = ScanHistoryService(
      cipher: cipher,
      pendingCipher: pending,
      directoryProvider: () async => d,
    );
  });
  tearDown(() async {
    await d.delete(recursive: true);
  });
  test(
    'completion and edits seal one ID with no authentication; explicit history merges updated answers',
    () async {
      await queue();
      final revised = const ClinicalChecklistResult(
        selectedSymptoms: {'fever': true},
        answers: {'fever': 'yes'},
      );
      await queue(checklist: revised);
      expect(cipher.prompts, 0);
      expect(pending.seals, 2);
      expect(pending.opens, 0);
      final file = await envelope();
      expect(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
        isNot(contains('fever')),
      );
      expect(await File('${d.path}/history.v2.enc').exists(), false);
      final records = await service.loadRecords();
      expect(cipher.prompts, 1);
      expect(records.length, 1);
      expect(records.single.checklistResult.answers['fever'], 'yes');
      expect(
        records.single.scanResult.rows.map((r) => r.result),
        fixture.baseScan().rows.map((r) => r.result),
      );
      expect(await Directory('${d.path}/pending').list().isEmpty, true);
    },
  );
  test(
    'photos remain sealed and import without a plaintext history copy',
    () async {
      final photo = File('${d.path}/capture.jpg');
      await photo.writeAsBytes([10, 20, 30, 40]);
      await queue(scan: fixture.baseScan().copyWith(imagePath: photo.path));
      expect(cipher.prompts, 0);
      final record = (await service.loadRecords()).single;
      expect(record.scanResult.imagePath.endsWith('.enc'), true);
      expect(await service.readImage(record.scanResult.imagePath), [
        10,
        20,
        30,
        40,
      ]);
      expect(
        await photo.exists(),
        true,
      ); // Never delete caller-owned camera/gallery original.
    },
  );
  test(
    'cancelled unlock and damaged envelope preserve files and existing index',
    () async {
      await queue();
      cipher.cancelled = true;
      await expectLater(service.loadRecords(), throwsStateError);
      expect(await (await envelope()).exists(), true);
      cipher.cancelled = false;
      await service.loadRecords();
      final original = await File('${d.path}/history.v2.enc').readAsBytes();
      await queue(scan: fixture.baseScan().copyWith(id: 'second'));
      final f = await envelope();
      final bytes = await f.readAsBytes();
      bytes[0] ^= 1;
      await f.writeAsBytes(bytes);
      await expectLater(
        service.loadRecords(),
        throwsA(isA<PlatformException>()),
      );
      expect(await File('${d.path}/history.v2.enc').readAsBytes(), original);
      expect(await f.readAsBytes(), bytes);
    },
  );
  test(
    'pending same-ID update preserves patient name; deleted IDs cannot resurrect',
    () async {
      await queue();
      await service.loadRecords();
      await service.updatePatientName('provisional', 'Patient A');
      await queue();
      expect((await service.loadRecords()).single.patientName, 'Patient A');
      await service.deleteRecord('provisional');
      await queue();
      expect(await service.loadRecords(), isEmpty);
    },
  );
  test(
    'scan duplicate checks never prompt, detect cached duplicates, and fail closed after disk changes',
    () async {
      final s = fixture.baseScan();
      final p = s.provenance!;
      await queue();
      final match = await service.findDuplicate(
        contentSha256: p.contentSha256,
        pixelSha256: p.pixelSha256,
        fingerprint: p.imageFingerprint,
        promptForAuthentication: false,
      );
      expect(match, isNotNull);
      expect(cipher.prompts, 0);
      await (await envelope()).writeAsBytes([1, 2, 3]);
      await expectLater(
        service.findDuplicate(
          contentSha256: p.contentSha256,
          pixelSha256: p.pixelSha256,
          fingerprint: p.imageFingerprint,
          promptForAuthentication: false,
        ),
        throwsStateError,
      );
      expect(cipher.prompts, 0);
    },
  );
  test(
    'interrupted first sealed write is authenticated before recovery',
    () async {
      await queue();
      final f = await envelope();
      await f.rename('${f.path}.tmp');
      expect((await service.loadRecords()).single.id, 'provisional');
      expect(cipher.prompts, 1);
      expect(await Directory('${d.path}/pending').list().isEmpty, true);
    },
  );
}
