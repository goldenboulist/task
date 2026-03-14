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
            updated_at  TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<Task>> getAllActiveTasks() async {
    final d = await db;
    final rows = await d.query('tasks', orderBy: 'created_at DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<void> upsertTask(Task task) async {
    final d = await db;
    await d.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(String id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Called after a successful sync — replace everything with the server list.
  Future<void> replaceAllTasks(List<Task> tasks) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('tasks');
      for (final t in tasks) {
        await txn.insert('tasks', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}