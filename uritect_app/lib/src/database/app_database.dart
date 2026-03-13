import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../analysis/knn_reference_map.dart';

// ─── Record Models ───────────────────────────────────────────────────────────

class KnnSampleRecord {
  const KnnSampleRecord({
    this.id,
    required this.analyteName,
    required this.level,
    required this.r,
    required this.g,
    required this.b,
    required this.h,
    required this.s,
    required this.v,
    required this.source,
    required this.batchId,
    required this.sessionId,
    required this.createdAt,
  });

  final int? id;
  final String analyteName;
  final String level;
  final int r;
  final int g;
  final int b;
  final double h;
  final double s;
  final double v;
  final String source;
  final String batchId;
  final String sessionId;
  final String createdAt;

  Map<String, dynamic> toMap() => {
        'analyte_name': analyteName,
        'level': level,
        'r': r,
        'g': g,
        'b': b,
        'h': h,
        's': s,
        'v': v,
        'source': source,
        'batch_id': batchId,
        'session_id': sessionId,
        'created_at': createdAt,
      };

  static KnnSampleRecord fromMap(Map<String, dynamic> map) => KnnSampleRecord(
        id: map['id'] as int?,
        analyteName: map['analyte_name'] as String,
        level: map['level'] as String,
        r: map['r'] as int,
        g: map['g'] as int,
        b: map['b'] as int,
        h: (map['h'] as num).toDouble(),
        s: (map['s'] as num).toDouble(),
        v: (map['v'] as num).toDouble(),
        source: map['source'] as String,
        batchId: map['batch_id'] as String,
        sessionId: map['session_id'] as String,
        createdAt: map['created_at'] as String,
      );
}

class AnalysisSessionRecord {
  const AnalysisSessionRecord({
    this.id,
    required this.sessionUuid,
    required this.timestamp,
    required this.phase,
    required this.batchId,
    required this.lightKelvin,
    this.controlLevel,
    this.markerConfidence,
    this.notes,
  });

  final int? id;
  final String sessionUuid;
  final String timestamp;
  final String phase;
  final String batchId;
  final int lightKelvin;
  final String? controlLevel;
  final double? markerConfidence;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'session_uuid': sessionUuid,
        'timestamp': timestamp,
        'phase': phase,
        'batch_id': batchId,
        'light_kelvin': lightKelvin,
        'control_level': controlLevel,
        'marker_confidence': markerConfidence,
        'notes': notes,
      };

  static AnalysisSessionRecord fromMap(Map<String, dynamic> map) =>
      AnalysisSessionRecord(
        id: map['id'] as int?,
        sessionUuid: map['session_uuid'] as String,
        timestamp: map['timestamp'] as String,
        phase: map['phase'] as String,
        batchId: map['batch_id'] as String,
        lightKelvin: map['light_kelvin'] as int,
        controlLevel: map['control_level'] as String?,
        markerConfidence: map['marker_confidence'] == null
            ? null
            : (map['marker_confidence'] as num).toDouble(),
        notes: map['notes'] as String?,
      );
}

class AnalysisResultRecord {
  const AnalysisResultRecord({
    this.id,
    required this.sessionUuid,
    required this.analyteName,
    required this.rawR,
    required this.rawG,
    required this.rawB,
    required this.corrR,
    required this.corrG,
    required this.corrB,
    required this.h,
    required this.s,
    required this.v,
    required this.nearestMatch,
    this.cropImagePath,
  });

  final int? id;
  final String sessionUuid;
  final String analyteName;
  final int rawR;
  final int rawG;
  final int rawB;
  final int corrR;
  final int corrG;
  final int corrB;
  final double h;
  final double s;
  final double v;
  final String nearestMatch;
  final String? cropImagePath;

  Map<String, dynamic> toMap() => {
        'session_uuid': sessionUuid,
        'analyte_name': analyteName,
        'raw_r': rawR,
        'raw_g': rawG,
        'raw_b': rawB,
        'corr_r': corrR,
        'corr_g': corrG,
        'corr_b': corrB,
        'h': h,
        's': s,
        'v': v,
        'nearest_match': nearestMatch,
        'crop_image_path': cropImagePath,
      };

  static AnalysisResultRecord fromMap(Map<String, dynamic> map) =>
      AnalysisResultRecord(
        id: map['id'] as int?,
        sessionUuid: map['session_uuid'] as String,
        analyteName: map['analyte_name'] as String,
        rawR: map['raw_r'] as int,
        rawG: map['raw_g'] as int,
        rawB: map['raw_b'] as int,
        corrR: map['corr_r'] as int,
        corrG: map['corr_g'] as int,
        corrB: map['corr_b'] as int,
        h: (map['h'] as num).toDouble(),
        s: (map['s'] as num).toDouble(),
        v: (map['v'] as num).toDouble(),
        nearestMatch: map['nearest_match'] as String,
        cropImagePath: map['crop_image_path'] as String?,
      );
}

// ─── Database Singleton ──────────────────────────────────────────────────────

class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'uritect.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE knn_reference_samples (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        analyte_name TEXT NOT NULL,
        level        TEXT NOT NULL,
        r            INTEGER NOT NULL,
        g            INTEGER NOT NULL,
        b            INTEGER NOT NULL,
        h            REAL NOT NULL,
        s            REAL NOT NULL,
        v            REAL NOT NULL,
        source       TEXT NOT NULL,
        batch_id     TEXT NOT NULL,
        session_id   TEXT NOT NULL,
        created_at   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE analysis_sessions (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        session_uuid      TEXT NOT NULL UNIQUE,
        timestamp         TEXT NOT NULL,
        phase             TEXT NOT NULL,
        batch_id          TEXT NOT NULL,
        light_kelvin      INTEGER NOT NULL,
        control_level     TEXT,
        marker_confidence REAL,
        notes             TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE analysis_results (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        session_uuid     TEXT NOT NULL,
        analyte_name     TEXT NOT NULL,
        raw_r            INTEGER NOT NULL,
        raw_g            INTEGER NOT NULL,
        raw_b            INTEGER NOT NULL,
        corr_r           INTEGER NOT NULL,
        corr_g           INTEGER NOT NULL,
        corr_b           INTEGER NOT NULL,
        h                REAL NOT NULL,
        s                REAL NOT NULL,
        v                REAL NOT NULL,
        nearest_match    TEXT NOT NULL,
        crop_image_path  TEXT
      )
    ''');
  }

  // ─── knn_reference_samples ──────────────────────────────────────────────

  Future<void> insertKnnSamples(List<KnnSampleRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('knn_reference_samples', record.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<KnnSampleRecord>> getAllKnnSamples() async {
    final db = await database;
    final rows =
        await db.query('knn_reference_samples', orderBy: 'created_at DESC');
    return rows.map(KnnSampleRecord.fromMap).toList();
  }

  Future<int> getKnnSampleCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) FROM knn_reference_samples');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Builds a [KnnReferenceMap] from all stored reference samples.
  /// Returns a map grouped by analyte name, each with its stored level and
  /// corrected RGB colour as the reference colour.
  Future<KnnReferenceMap> buildKnnReferenceMap() async {
    final samples = await getAllKnnSamples();
    final map = <String, List<ParameterThreshold>>{};

    for (final sample in samples) {
      final color = Color.fromARGB(255, sample.r, sample.g, sample.b);
      map.putIfAbsent(sample.analyteName, () => []).add(
        ParameterThreshold(
          level: sample.level,
          referenceColor: color,
          weight: 1.0,
        ),
      );
    }

    return KnnReferenceMap(map: map);
  }

  // ─── analysis_sessions ──────────────────────────────────────────────────

  Future<void> insertSession(AnalysisSessionRecord record) async {
    final db = await database;
    await db.insert(
      'analysis_sessions',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AnalysisSessionRecord>> getAllSessions() async {
    final db = await database;
    final rows =
        await db.query('analysis_sessions', orderBy: 'timestamp DESC');
    return rows.map(AnalysisSessionRecord.fromMap).toList();
  }

  Future<void> deleteSession(String sessionUuid) async {
    final db = await database;
    await db.delete(
      'analysis_sessions',
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
    );
    await db.delete(
      'analysis_results',
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
    );
  }

  // ─── analysis_results ───────────────────────────────────────────────────

  Future<void> insertResults(List<AnalysisResultRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('analysis_results', record.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<AnalysisResultRecord>> getResultsForSession(
      String sessionUuid) async {
    final db = await database;
    final rows = await db.query(
      'analysis_results',
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
    );
    return rows.map(AnalysisResultRecord.fromMap).toList();
  }
}
