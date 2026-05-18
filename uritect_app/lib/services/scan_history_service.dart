import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/clinical_symptoms.dart';
import '../models/saved_scan_record.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';

class ScanHistoryService {
  const ScanHistoryService();

  Future<Directory> _historyDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/scan_history');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _indexFile() async {
    final directory = await _historyDirectory();
    return File('${directory.path}/history.json');
  }

  Future<String> _persistImage(String sourcePath, String scanId) async {
    if (sourcePath.isEmpty) {
      return sourcePath;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      return sourcePath;
    }

    final directory = await _historyDirectory();
    final imagesDirectory = Directory('${directory.path}/images');
    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    final extension = source.uri.pathSegments.last.contains('.')
        ? '.${source.uri.pathSegments.last.split('.').last}'
        : '.jpg';
    final destination = File('${imagesDirectory.path}/$scanId$extension');

    if (source.path == destination.path) {
      return destination.path;
    }

    await source.copy(destination.path);
    return destination.path;
  }

  Future<List<SavedScanRecord>> loadRecords() async {
    final file = await _indexFile();
    if (!await file.exists()) {
      return <SavedScanRecord>[];
    }

    try {
      final payload = jsonDecode(await file.readAsString());
      final items = payload is List ? payload : const [];
      final records = items
          .whereType<Map<String, dynamic>>()
          .map(SavedScanRecord.fromJson)
          .toList();
      records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return records;
    } on FormatException {
      return <SavedScanRecord>[];
    }
  }

  Future<SavedScanRecord> saveCompletedScan({
    required ScanResult scanResult,
    required ClinicalChecklistResult checklistResult,
    required ScreeningFusionResult fusionResult,
  }) async {
    final savedImagePath = await _persistImage(
      scanResult.imagePath,
      scanResult.id,
    );
    final persistedScan = scanResult.copyWith(imagePath: savedImagePath);
    final record = SavedScanRecord.fromAnalysis(
      scanResult: persistedScan,
      checklistResult: checklistResult,
      fusionResult: fusionResult,
    );

    final records = await loadRecords();
    final withoutDuplicate = records
        .where((item) => item.id != record.id)
        .toList();
    withoutDuplicate.insert(0, record);

    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(withoutDuplicate.map((item) => item.toJson()).toList()),
      flush: true,
    );
    return record;
  }

  Future<bool> deleteRecord(String recordId) async {
    final records = await loadRecords();
    SavedScanRecord? recordToDelete;
    final remaining = <SavedScanRecord>[];

    for (final record in records) {
      if (record.id == recordId) {
        recordToDelete = record;
      } else {
        remaining.add(record);
      }
    }

    if (recordToDelete == null) {
      return false;
    }

    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(remaining.map((item) => item.toJson()).toList()),
      flush: true,
    );

    final imagePath = recordToDelete.scanResult.imagePath;
    if (imagePath.isNotEmpty) {
      final directory = await _historyDirectory();
      final imageFile = File(imagePath);
      if (imagePath.startsWith(directory.path) && await imageFile.exists()) {
        await imageFile.delete();
      }
    }

    return true;
  }
}
