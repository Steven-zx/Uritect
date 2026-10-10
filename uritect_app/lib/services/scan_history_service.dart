import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clinical_symptoms.dart';
import '../models/saved_scan_record.dart';
import '../models/renal_followup.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../models/scan_provenance.dart';
import 'history_cipher.dart';

class ScanHistoryService {
  final HistoryCipher cipher;
  final Future<Directory> Function()? directoryProvider;
  const ScanHistoryService({
    this.cipher = const PlatformHistoryCipher(),
    this.directoryProvider,
  });
  static Future<void> _queue = Future.value();
  static String? recoveryNotice;
  Future<T> _serial<T>(Future<T> Function() action) {
    final complete = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        complete.complete(await action());
      } catch (error, stack) {
        complete.completeError(error, stack);
      }
    });
    return complete.future;
  }

  Future<Directory> _directory() async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : Directory(
            '${(await getApplicationDocumentsDirectory()).path}/scan_history',
          );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> lock() => cipher.lock();
  Future<void> authenticate() => cipher.authenticate();
  Future<void> discardTemporaryImage(String path) async {
    if (path.isEmpty) return;
    try {
      final temporary = await getTemporaryDirectory();
      final source = File(path);
      if (await _owns(temporary, source)) await source.delete();
    } catch (_) {
      /* Never delete an unverified path or a Gallery/Camera original. */
    }
  }

  File _file(Directory d, String name) => File('${d.path}/$name');
  Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));
  Future<bool> _owns(Directory directory, File file) async {
    if (!await file.exists()) return false;
    final root = await directory.resolveSymbolicLinks();
    final target = await file.resolveSymbolicLinks();
    return target.startsWith('$root${Platform.pathSeparator}');
  }

  Future<void> _finishLegacyMigration(
    Directory d,
    List<SavedScanRecord> records,
  ) async {
    final legacy = _file(d, 'history.json');
    if (!await legacy.exists()) return;
    final payload = jsonDecode(await legacy.readAsString());
    if (payload is! List) {
      throw const FormatException('Legacy history is not a list.');
    }
    final old = _records(payload);
    final backup = await _readIndex(_file(d, 'history.recovery.enc'));
    final deleted = await _deleted(d);
    final sources = <File>[];
    for (final prior in old) {
      if (deleted.contains(prior.id)) continue;
      final current = records.where((r) => r.id == prior.id).toList();
      if (current.length != 1 || !backup.any((r) => r.id == prior.id)) {
        throw const FormatException('Incomplete legacy migration.');
      }
      final expected = prior.toJson()
        ..['scanResult'] = prior.scanResult
            .copyWith(imagePath: current.single.scanResult.imagePath)
            .toJson();
      if (jsonEncode(expected) != jsonEncode(current.single.toJson())) {
        throw const FormatException('Conflicting legacy record.');
      }
      final source = File(prior.scanResult.imagePath);
      if (await source.exists()) {
        if (!await _owns(d, source)) {
          throw const FormatException(
            'Legacy photo is outside private history storage.',
          );
        }
        final protected = await _readImage(
          d,
          current.single.scanResult.imagePath,
        );
        if (sha256.convert(protected) !=
            sha256.convert(await source.readAsBytes())) {
          throw const FormatException('Legacy photo mismatch.');
        }
        sources.add(source);
      }
    }
    // Both indexes and all existing private photos verified before plaintext removal.
    await legacy.delete();
    for (final source in sources) {
      if (await source.exists()) await source.delete();
    }
    recoveryNotice =
        'Existing history was migrated to protected storage. Records lacking current safety evidence remain unverified archives.';
  }

  Future<void> _atomic(File destination, Uint8List bytes) async {
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
  }

  Future<List<SavedScanRecord>> _readIndex(File file) async {
    final bytes = await cipher.decrypt(
      await file.readAsBytes(),
      'uritect:index:v2',
    );
    final payload = jsonDecode(utf8.decode(bytes));
    if (payload is! Map<String, dynamic> ||
        payload['schema'] != 2 ||
        payload['records'] is! List) {
      throw const FormatException('Unexpected protected history format.');
    }
    return _records(payload['records'] as List);
  }

  List<SavedScanRecord> _records(List items) {
    final records = <SavedScanRecord>[];
    final ids = <String>{};
    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          !ids.add(item['id'] as String) ||
          DateTime.tryParse(item['savedAt'] as String? ?? '') == null ||
          item['scanResult'] is! Map<String, dynamic> ||
          item['checklistResult'] is! Map<String, dynamic>) {
        throw const FormatException('Malformed or duplicate history record.');
      }
      final record = SavedScanRecord.fromJson(item);
      if (record.id != record.scanResult.id) {
        throw const FormatException('History identity mismatch.');
      }
      records.add(record);
    }
    records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return records;
  }

  void _rethrowAccessFailure(Object error) {
    if (error is PlatformException && error.code != 'HISTORY_INTEGRITY_ERROR') {
      throw error;
    }
  }

  Future<Set<String>> _deleted(Directory d) async {
    final file = _file(d, 'deleted.v2.enc');
    if (!await file.exists()) return {};
    try {
      final payload = jsonDecode(
        utf8.decode(
          await cipher.decrypt(
            await file.readAsBytes(),
            'uritect:deletions:v2',
          ),
        ),
      );
      if (payload is! List ||
          payload.any((id) => id is! String || id.isEmpty)) {
        throw const FormatException('Invalid deletion journal.');
      }
      return payload.cast<String>().toSet();
    } catch (error) {
      _rethrowAccessFailure(error);
      throw const HistoryCorruptionException(
        'The deletion journal cannot be verified. History files were preserved; no records were overwritten.',
      );
    }
  }

  Future<List<SavedScanRecord>> _load(Directory d) async {
    final primary = _file(d, 'history.v2.enc');
    final backup = _file(d, 'history.recovery.enc');
    final legacy = _file(d, 'history.json');
    List<SavedScanRecord>? records;
    if (await primary.exists()) {
      try {
        records = await _readIndex(primary);
      } catch (error) {
        _rethrowAccessFailure(error);
      }
    }
    if (records == null && await backup.exists()) {
      try {
        final recovered = await _readIndex(backup);
        if (await primary.exists()) {
          await primary.copy(
            '${primary.path}.corrupt.${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        await _atomic(primary, await backup.readAsBytes());
        records = recovered;
        recoveryNotice =
            'Recovered a previous history copy. Recent changes may be missing. The damaged file was preserved.';
      } catch (error) {
        _rethrowAccessFailure(error);
      }
    }
    if (records == null &&
        !await primary.exists() &&
        !await backup.exists() &&
        await legacy.exists()) {
      try {
        final payload = jsonDecode(await legacy.readAsString());
        if (payload is! List) {
          throw const FormatException('Legacy history is not a list.');
        }
        final oldRecords = _records(payload);
        final migrated = <SavedScanRecord>[];
        for (final record in oldRecords) {
          final image = File(record.scanResult.imagePath);
          if (await image.exists() && !await _owns(d, image)) {
            throw const FormatException(
              'Legacy image outside private history.',
            );
          }
          final imagePath = await _persistImage(d, record.scanResult.imagePath);
          migrated.add(
            SavedScanRecord.fromJson(
              record.toJson()
                ..['scanResult'] = record.scanResult
                    .copyWith(imagePath: imagePath)
                    .toJson(),
            ),
          );
        }
        await _write(d, migrated);
        // Verify both committed encrypted copies before removing plaintext.
        await _readIndex(primary);
        await _readIndex(backup);
        await _finishLegacyMigration(d, migrated);
        records = migrated;
        recoveryNotice =
            'Existing history was migrated to protected storage. Records lacking current safety evidence remain unverified archives.';
      } catch (error) {
        _rethrowAccessFailure(error);
        throw const HistoryCorruptionException(
          'Existing history could not be migrated safely. Original files were preserved. Saving is blocked until recovery.',
        );
      }
    }
    if (records == null) {
      if (await primary.exists() || await backup.exists()) {
        throw const HistoryCorruptionException(
          'Saved history cannot be verified and no usable recovery copy is available. Files were preserved; saving is blocked until recovery.',
        );
      }
      final staging = _file(d, 'history.v2.enc.tmp');
      if (await staging.exists()) {
        try {
          records = await _readIndex(staging);
          await staging.rename(primary.path);
          await _atomic(backup, await primary.readAsBytes());
          recoveryNotice = 'Recovered an interrupted first save.';
        } catch (error) {
          _rethrowAccessFailure(error);
          throw const HistoryCorruptionException(
            'An interrupted save cannot be verified. Its file was preserved; saving is blocked until recovery.',
          );
        }
      } else {
        records = [];
      }
    }
    if (await legacy.exists()) {
      try {
        await _finishLegacyMigration(d, records);
      } catch (error) {
        _rethrowAccessFailure(error);
        throw const HistoryCorruptionException(
          'An interrupted legacy migration cannot be verified. Original files were preserved; saving is blocked until recovery.',
        );
      }
    }
    final deleted = await _deleted(d);
    return records.where((r) => !deleted.contains(r.id)).toList();
  }

  Future<void> _write(Directory d, List<SavedScanRecord> records) async {
    final payload = jsonEncode({
      'schema': 2,
      'records': records.map((r) => r.toJson()).toList(),
    });
    final encrypted = await cipher.encrypt(_bytes(payload), 'uritect:index:v2');
    // A cipher/authentication failure must happen before replacing any index.
    if (utf8.decode(await cipher.decrypt(encrypted, 'uritect:index:v2')) !=
        payload) {
      throw const HistoryCorruptionException(
        'Protected history verification failed.',
      );
    }
    final primary = _file(d, 'history.v2.enc');
    final backup = _file(d, 'history.recovery.enc');
    if (await primary.exists()) {
      await _readIndex(primary);
      await _atomic(backup, await primary.readAsBytes());
    }
    await _atomic(primary, encrypted);
    if (!await backup.exists()) await _atomic(backup, encrypted);
  }

  Future<String> _persistImage(Directory d, String sourcePath) async {
    if (sourcePath.isEmpty) return '';
    final source = File(sourcePath);
    if (!await source.exists()) return '';
    if (sourcePath.endsWith('.enc') && await _owns(d, source)) {
      await cipher.decrypt(
        await source.readAsBytes(),
        'uritect:image:${source.uri.pathSegments.last}',
      );
      return source.path;
    }
    final bytes = await source.readAsBytes();
    final name = '${sha256.convert(bytes)}.enc';
    final directory = Directory('${d.path}/images');
    await directory.create(recursive: true);
    if (!(await directory.resolveSymbolicLinks()).startsWith(
      '${await d.resolveSymbolicLinks()}${Platform.pathSeparator}',
    )) {
      throw StateError('Invalid protected photo directory.');
    }
    final destination = File('${directory.path}/$name');
    final encrypted = await cipher.encrypt(bytes, 'uritect:image:$name');
    if (sha256.convert(
          await cipher.decrypt(encrypted, 'uritect:image:$name'),
        ) !=
        sha256.convert(bytes)) {
      throw const HistoryCorruptionException(
        'Photo encryption could not be verified.',
      );
    }
    await _atomic(destination, encrypted);
    return destination.path;
  }

  Future<List<SavedScanRecord>> loadRecords() => _serial(() async {
    await cipher.authenticate();
    return _load(await _directory());
  });
  Future<ImageMatch?> findDuplicate({
    required String contentSha256,
    required String pixelSha256,
    required String fingerprint,
  }) => _serial(() async {
    final d = await _directory();
    if (!await _file(d, 'history.v2.enc').exists() &&
        !await _file(d, 'history.recovery.enc').exists() &&
        !await _file(d, 'history.json').exists() &&
        !await _file(d, 'history.v2.enc.tmp').exists()) {
      return null;
    }
    await cipher.authenticate();
    ImageMatch? similar;
    for (final record in await _load(d)) {
      final p = record.scanResult.provenance;
      if (p != null &&
          (p.contentSha256 == contentSha256 || p.pixelSha256 == pixelSha256)) {
        return ImageMatch(record.id, true);
      }
      if (p != null && p.imageFingerprint == fingerprint) {
        similar ??= ImageMatch(record.id, false);
      }
      // Older records have no hashes; compare their authenticated saved photo.
      if (p == null && record.scanResult.imagePath.endsWith('.enc')) {
        final bytes = await _readImage(d, record.scanResult.imagePath);
        if (sha256.convert(bytes).toString() == contentSha256) {
          return ImageMatch(record.id, true);
        }
      }
    }
    return similar;
  });
  Future<Uint8List> _readImage(Directory d, String path) async {
    final file = File(path);
    if (!path.endsWith('.enc') || !await _owns(d, file)) {
      throw StateError('Unprotected history image is not readable.');
    }
    return cipher.decrypt(
      await file.readAsBytes(),
      'uritect:image:${file.uri.pathSegments.last}',
    );
  }

  Future<Uint8List> readImage(String path) async =>
      _readImage(await _directory(), path);
  Future<SavedScanRecord> saveCompletedScan({
    required ScanResult scanResult,
    required ClinicalChecklistResult checklistResult,
    required ScreeningFusionResult fusionResult,
    required RenalFollowupResult renalFollowupResult,
  }) => _serial(() async {
    await cipher.authenticate();
    final d = await _directory();
    final records = await _load(
      d,
    ); // Validate/recover BEFORE writing a photo or index.
    if ((await _deleted(d)).contains(scanResult.id)) {
      throw StateError(
        'A deleted record cannot be restored by resaving its ID.',
      );
    }
    final path = await _persistImage(d, scanResult.imagePath);
    final record = SavedScanRecord.fromAnalysis(
      scanResult: scanResult.copyWith(imagePath: path),
      checklistResult: checklistResult,
      fusionResult: fusionResult,
      renalFollowupResult: renalFollowupResult,
    );
    await _write(d, [record, ...records.where((r) => r.id != record.id)]);
    // Remove only our private temporary copy, never a Camera/Gallery original.
    if (directoryProvider == null) {
      try {
        final temporary = await getTemporaryDirectory();
        final source = File(scanResult.imagePath);
        if (await _owns(temporary, source)) await source.delete();
      } catch (_) {
        /* The encrypted record is already committed. Do not report a false save failure. */
      }
    }
    return record;
  });
  Future<bool> deleteRecord(String id) => _serial(() async {
    await cipher.authenticate();
    final d = await _directory();
    final records = await _load(d);
    final matches = records.where((r) => r.id == id).toList();
    if (matches.isEmpty) return false;
    final deleted = await _deleted(d);
    deleted.add(id);
    // Persist deletion first: an older recovery index cannot resurrect this ID.
    await _atomic(
      _file(d, 'deleted.v2.enc'),
      await cipher.encrypt(
        _bytes(jsonEncode(deleted.toList())),
        'uritect:deletions:v2',
      ),
    );
    final remaining = records.where((r) => r.id != id).toList();
    await _write(d, remaining);
    for (final record in matches) {
      final path = record.scanResult.imagePath;
      if (path.isNotEmpty &&
          !remaining.any((r) => r.scanResult.imagePath == path)) {
        final file = File(path);
        if (await _owns(d, file)) await file.delete();
      }
    }
    return true;
  });

  Future<SavedScanRecord> updatePatientName(String id, String? name) =>
      _serial(() async {
        final normalized = SavedScanRecord.normalizePatientName(name);
        await cipher.authenticate();
        final directory = await _directory();
        final records = await _load(directory);
        final index = records.indexWhere((record) => record.id == id);
        if (index < 0) {
          throw StateError('This saved scan is no longer available.');
        }
        final updated = records[index].withPatientName(normalized);
        records[index] = updated;
        await _write(directory, records);
        return updated;
      });
}
