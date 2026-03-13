import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class LocalDb {
  LocalDb._();
  static final instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'tasks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tasks (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            due_date    TEXT,
            completed   INTEGER NOT NULL DEFAULT 0,
            created_at  TEXT NOT NULL,
            updated_at  TEXT NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0,
            is_deleted  INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key   TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  // ── Tasks ─────────────────────────────────────────────────────

  Future<List<Task>> getAllActiveTasks() async {
    final d = await db;
    final rows = await d.query(
      'tasks',
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getPendingTasks() async {
    final d = await db;
    final rows = await d.query('tasks', where: 'synced = 0 AND is_deleted = 0');
    return rows.map(Task.fromMap).toList();
  }

  Future<void> upsertTask(Task task) async {
    final d = await db;
    await d.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(List<Task> tasks) async {
    final d = await db;
    final batch = d.batch();
    for (final t in tasks) {
      batch.insert('tasks', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Merge tasks arriving from the server using last-write-wins on updated_at.
  Future<void> mergeServerTasks(List<Task> serverTasks) async {
    final d = await db;
    final batch = d.batch();
    for (final remote in serverTasks) {
      final rows = await d.query('tasks', where: 'id = ?', whereArgs: [remote.id]);
      if (rows.isEmpty) {
        // New task from server — insert it (marked synced)
        batch.insert('tasks', remote.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        final local = Task.fromMap(rows.first);
        // Server wins only if its timestamp is newer
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          batch.insert('tasks', remote.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final id in ids) {
      batch.update('tasks', {'synced': 1},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Clean up tasks that are both synced and deleted (no longer needed)
  Future<void> cleanupSyncedDeletedTasks() async {
    final d = await db;
    await d.delete('tasks', where: 'synced = 1 AND is_deleted = 1');
  }

  // ── Meta (last_sync timestamp) ────────────────────────────────

  Future<String?> getMeta(String key) async {
    final d = await db;
    final rows = await d.query('meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final d = await db;
    await d.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
