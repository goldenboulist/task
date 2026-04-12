import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/flash_category.dart';
import '../models/flash_card.dart';
import '../models/song.dart';
import '../models/playlist.dart';

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
      version: 3,
      onCreate: (db, _) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
        if (oldVersion < 3) await _createV3(db);
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

  Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE songs (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        artist      TEXT NOT NULL DEFAULT '',
        duration_ms INTEGER NOT NULL DEFAULT 0,
        local_path  TEXT,
        synced      INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE playlists (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id TEXT NOT NULL,
        song_id     TEXT NOT NULL,
        added_at    TEXT NOT NULL,
        PRIMARY KEY (playlist_id, song_id)
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

  // ── Songs ────────────────────────────────────────────────────

  Future<List<Song>> getAllSongs() async {
    final d = await db;
    final rows = await d.query('songs', orderBy: 'title ASC');
    return rows.map(Song.fromMap).toList();
  }

  Future<void> upsertSong(Song song) async {
    final d = await db;
    await d.insert('songs', song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSong(String id) async {
    final d = await db;
    await d.delete('playlist_songs', where: 'song_id = ?', whereArgs: [id]);
    await d.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  /// Replace all songs with the server-canonical list.
  /// Callers must preserve localPath/synced before calling this.
  Future<void> replaceAllSongs(List<Song> songs) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('songs');
      for (final s in songs) {
        await txn.insert('songs', s.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── Playlists ─────────────────────────────────────────────────

  Future<List<Playlist>> getAllPlaylists() async {
    final d = await db;
    final rows = await d.query('playlists', orderBy: 'name ASC');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<void> upsertPlaylist(Playlist playlist) async {
    final d = await db;
    await d.insert('playlists', playlist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePlaylist(String id) async {
    final d = await db;
    await d.delete('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [id]);
    await d.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllPlaylists(
    List<Playlist> playlists,
    Map<String, List<String>> playlistSongs,
  ) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('playlist_songs');
      await txn.delete('playlists');
      final now = DateTime.now().toUtc().toIso8601String();
      for (final pl in playlists) {
        await txn.insert('playlists', pl.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        final sids = playlistSongs[pl.id] ?? [];
        for (final sid in sids) {
          await txn.insert(
            'playlist_songs',
            {'playlist_id': pl.id, 'song_id': sid, 'added_at': now},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  // ── Playlist ↔ Song junction ──────────────────────────────────

  Future<List<String>> getSongIdsForPlaylist(String playlistId) async {
    final d = await db;
    final rows = await d.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'added_at ASC',
    );
    return rows.map((r) => r['song_id'] as String).toList();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final d = await db;
    await d.insert(
      'playlist_songs',
      {
        'playlist_id': playlistId,
        'song_id': songId,
        'added_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    final d = await db;
    await d.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
  }
}
