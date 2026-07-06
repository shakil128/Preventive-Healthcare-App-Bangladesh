/// Offline-first local database (SQLite via sqflite).
///
/// The field app must work fully offline: every read and write goes to this
/// local store first. Entities are stored as JSON blobs keyed by id (simple and
/// robust); writes also enqueue a [SyncQueueItem] so the app can show a pending
/// count and flush to the backend when connectivity returns.
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/seed.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'mch_surveillance.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE beneficiaries (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute('CREATE TABLE workers (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
          'CREATE TABLE sync_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT, ref_id TEXT, label TEXT, created_at INTEGER)',
        );
        await _seed(db);
      },
    );
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();
    for (final b in seedBeneficiaries()) {
      batch.insert('beneficiaries', {'id': b.id, 'data': jsonEncode(b.toJson())});
    }
    for (final w in seedWorkers()) {
      batch.insert('workers', {'id': w.id, 'data': jsonEncode(w.toJson())});
    }
    for (final item in seedBacklog()) {
      batch.insert('sync_queue', {
        'kind': item.kind,
        'ref_id': item.refId,
        'label': item.label,
        'created_at': item.createdAt,
      });
    }
    await batch.commit(noResult: true);
  }

  // ---- Beneficiaries ----

  Future<List<Beneficiary>> beneficiaries() async {
    final db = await _database;
    final rows = await db.query('beneficiaries');
    return rows
        .map((r) => Beneficiary.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<Beneficiary?> beneficiary(String id) async {
    final db = await _database;
    final rows = await db.query('beneficiaries', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Beneficiary.fromJson(jsonDecode(rows.first['data'] as String) as Map<String, dynamic>);
  }

  Future<void> putBeneficiary(Beneficiary b) async {
    final db = await _database;
    await db.insert(
      'beneficiaries',
      {'id': b.id, 'data': jsonEncode(b.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Refresh the whole beneficiary cache from an authoritative backend snapshot.
  Future<void> replaceBeneficiaries(List<Beneficiary> list) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('beneficiaries');
    for (final b in list) {
      batch.insert('beneficiaries', {'id': b.id, 'data': jsonEncode(b.toJson())});
    }
    await batch.commit(noResult: true);
  }

  // ---- Workers ----

  Future<List<Worker>> workers() async {
    final db = await _database;
    final rows = await db.query('workers');
    return rows
        .map((r) => Worker.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> putWorker(Worker w) async {
    final db = await _database;
    await db.insert(
      'workers',
      {'id': w.id, 'data': jsonEncode(w.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Refresh the whole worker cache from an authoritative backend snapshot.
  Future<void> replaceWorkers(List<Worker> list) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('workers');
    for (final w in list) {
      batch.insert('workers', {'id': w.id, 'data': jsonEncode(w.toJson())});
    }
    await batch.commit(noResult: true);
  }

  // ---- Sync queue ----

  Future<void> enqueue(String kind, String refId, String label) async {
    final db = await _database;
    await db.insert('sync_queue', {
      'kind': kind,
      'ref_id': refId,
      'label': label,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> pendingCount() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<SyncQueueItem>> pendingItems() async {
    final db = await _database;
    final rows = await db.query('sync_queue', orderBy: 'created_at ASC');
    return rows
        .map((r) => SyncQueueItem(
              id: r['id'] as int?,
              kind: r['kind'] as String,
              refId: r['ref_id'] as String,
              label: r['label'] as String,
              createdAt: r['created_at'] as int,
            ))
        .toList();
  }

  /// Clear only the acknowledged records (those the server confirmed).
  Future<void> clearAcknowledged(Set<String> refIds) async {
    if (refIds.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(refIds.length, '?').join(',');
    await db.delete('sync_queue', where: 'ref_id IN ($placeholders)', whereArgs: refIds.toList());
  }
}
