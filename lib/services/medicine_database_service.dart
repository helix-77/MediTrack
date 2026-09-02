import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/generic_reference.dart';
import '../models/medicine_reference.dart';

class MedicineDatabaseService {
  static final MedicineDatabaseService _instance = MedicineDatabaseService._internal();
  factory MedicineDatabaseService() => _instance;
  MedicineDatabaseService._internal();

  Database? _db;
  bool _isInitializing = false;

  static const String _dbName = 'medicine_catalog.db';
  static const String _assetPath = 'assets/data/medicine_catalog.db';

  /// Ensures database is extracted from assets to local storage and opened.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    
    // Wait if another call is currently initializing
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_db != null && _db!.isOpen) return _db!;
    }

    _isInitializing = true;
    try {
      _db = await _initDatabase();
      return _db!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    final exists = await databaseExists(path);

    if (!exists) {
      debugPrint('[MedicineDatabaseService] Creating database copy from assets...');
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      final ByteData data = await rootBundle.load(_assetPath);
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      debugPrint('[MedicineDatabaseService] Database successfully copied to: $path');
    }

    return await openDatabase(path, readOnly: true);
  }

  /// Searches medicines using full-text search (FTS5) with fallback to standard prefix matching.
  Future<List<MedicineReference>> searchMedicines(
    String query, {
    int limit = 35,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    final db = await database;

    // Build sanitized FTS5 query with prefix matching on tokens
    final tokens = clean
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '$t*')
        .toList();

    if (tokens.isNotEmpty) {
      final ftsMatch = tokens.join(' ');
      try {
        final List<Map<String, dynamic>> ftsResults = await db.rawQuery(
          '''
          SELECT m.id, m.brand_name, m.generic_name, m.dosage_form, m.strength, m.manufacturer, m.unit_price, m.search_name
          FROM medicines_fts f
          JOIN medicines m ON f.rowid = m.id
          WHERE medicines_fts MATCH ?
          ORDER BY (CASE WHEN m.unit_price IS NULL THEN 1 ELSE 0 END), m.unit_price ASC
          LIMIT ?
          ''',
          [ftsMatch, limit],
        );

        if (ftsResults.isNotEmpty) {
          return ftsResults.map((r) => MedicineReference.fromSqlite(r)).toList();
        }
      } catch (e) {
        debugPrint('[MedicineDatabaseService] FTS query error, falling back to LIKE: $e');
      }
    }

    // Fallback: LIKE query on search_name
    final searchPattern = '%${MedicineReference.normalizeSearchName(clean)}%';
    final List<Map<String, dynamic>> likeResults = await db.rawQuery(
      '''
      SELECT id, brand_name, generic_name, dosage_form, strength, manufacturer, unit_price, search_name
      FROM medicines
      WHERE search_name LIKE ?
      ORDER BY (CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END), unit_price ASC
      LIMIT ?
      ''',
      [searchPattern, limit],
    );

    return likeResults.map((r) => MedicineReference.fromSqlite(r)).toList();
  }

  /// Finds alternative brands with the same generic name, sorted by price (cheapest first).
  Future<List<MedicineReference>> getAlternativesForGeneric(
    String genericName, {
    String? excludeBrandId,
    int limit = 30,
  }) async {
    final trimmed = genericName.trim();
    if (trimmed.isEmpty) return [];

    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT id, brand_name, generic_name, dosage_form, strength, manufacturer, unit_price, search_name
      FROM medicines
      WHERE LOWER(generic_name) = LOWER(?) AND (? IS NULL OR CAST(id AS TEXT) != ?)
      ORDER BY (CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END), unit_price ASC
      LIMIT ?
      ''',
      [trimmed, excludeBrandId, excludeBrandId ?? '', limit],
    );

    return results.map((r) => MedicineReference.fromSqlite(r)).toList();
  }

  /// Retrieves comprehensive generic information including indications, pharmacology, and side effects.
  Future<GenericReference?> getGenericDetails(String genericName) async {
    final trimmed = genericName.trim();
    if (trimmed.isEmpty) return null;

    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT * FROM generics WHERE LOWER(generic_name) = LOWER(?) LIMIT 1',
      [trimmed],
    );

    if (results.isEmpty) return null;
    return GenericReference.fromSqlite(results.first);
  }

  /// Close connection if needed
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
