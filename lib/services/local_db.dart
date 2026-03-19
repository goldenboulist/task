import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/flash_category.dart';
import '../models/flash_card.dart';

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
      version: 2,
      onCreate: (db, _) async {
        await _createV1(db);
        await _createV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2(db);
        }
      },
    );
  }

  Future<void> _createV1(Database db) async {
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
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE flash_categories (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        color_value INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE flash_cards (
        id          TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        front       TEXT NOT NULL,
        back        TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
  }

  // ── Tasks ────────────────────────────────────────────────────

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

  // ── Flash Categories ─────────────────────────────────────────

  Future<List<FlashCategory>> getAllCategories() async {
    final d = await db;
    final rows = await d.query('flash_categories', orderBy: 'created_at ASC');
    final List<FlashCategory> categories = [];
    for (final row in rows) {
      final id = row['id'] as String;
      final countResult = await d.rawQuery(
        'SELECT COUNT(*) as c FROM flash_cards WHERE category_id = ?',
        [id],
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      categories.add(FlashCategory.fromMap(row, cardCount: count));
    }
    return categories;
  }

  Future<void> upsertCategory(FlashCategory cat) async {
    final d = await db;
    await d.insert('flash_categories', cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(String id) async {
    final d = await db;
    await d.delete('flash_cards', where: 'category_id = ?', whereArgs: [id]);
    await d.delete('flash_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── Flash Cards ──────────────────────────────────────────────

  Future<List<FlashCard>> getCardsForCategory(String categoryId) async {
    final d = await db;
    final rows = await d.query(
      'flash_cards',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at ASC',
    );
    return rows.map(FlashCard.fromMap).toList();
  }

  Future<void> upsertCard(FlashCard card) async {
    final d = await db;
    await d.insert('flash_cards', card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCard(String id) async {
    final d = await db;
    await d.delete('flash_cards', where: 'id = ?', whereArgs: [id]);
  }

  /// Called after a successful flash sync — replace everything with the
  /// server-authoritative lists. Cards are cleared before categories to
  /// avoid any transient FK issues on platforms that enforce them.
  Future<void> replaceAllFlashData(
    List<FlashCategory> categories,
    List<FlashCard> cards,
  ) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('flash_cards');
      await txn.delete('flash_categories');
      for (final c in categories) {
        await txn.insert('flash_categories', c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final c in cards) {
        await txn.insert('flash_cards', c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
