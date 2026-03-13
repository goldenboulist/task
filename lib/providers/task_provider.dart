import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

const _themeKey   = 'theme';
const _sortKey    = 'sortByDate';
// Legacy migration key
const _legacyKey  = 'task-manager-tasks';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _sortByDate  = true;
  bool _darkMode    = false;
  bool _initialized = false;

  bool get sortByDate  => _sortByDate;
  bool get darkMode    => _darkMode;
  bool get initialized => _initialized;

  int get totalTasks     => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.completed).length;

  SyncStatus get syncStatus => SyncService.instance.status;

  List<Task> get tasks {
    final sorted = [..._tasks];
    if (_sortByDate) {
      sorted.sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    } else {
      sorted.sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return sorted;
  }

  // ── Initialise ────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode  = prefs.getString(_themeKey) == 'dark';
    _sortByDate = prefs.getBool(_sortKey) ?? true;

    // One-time migration from SharedPreferences JSON → SQLite
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        final oldTasks = Task.legacyListFromJson(legacy);
        for (final t in oldTasks) {
          await LocalDb.instance.upsertTask(t);
        }
      } catch (_) {}
      await prefs.remove(_legacyKey);
    }

    await _reload();

    // Listen to sync events so UI can refresh after background sync
    SyncService.instance.statusStream.listen((status) async {
      if (status == SyncStatus.success) {
        await _reload();
      }
      notifyListeners();
    });

    // Start connectivity-aware background sync
    await SyncService.instance.init();

    _initialized = true;
    notifyListeners();
  }

  /// Reload the task list from SQLite into memory.
  Future<void> _reload() async {
    _tasks = await LocalDb.instance.getAllActiveTasks();
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────

  Future<void> addTask(String name, String description, DateTime? dueDate) async {
    final now = DateTime.now();
    final task = Task(
      id:          const Uuid().v4(),
      name:        name,
      description: description,
      dueDate:     dueDate,
      completed:   false,
      createdAt:   now,
      updatedAt:   now,
      synced:      false,
    );
    await LocalDb.instance.upsertTask(task);
    await _reload();
    _backgroundSync();
  }

  Future<void> editTask(
      String id, String name, String description, DateTime? dueDate) async {
    final existing = _tasks.firstWhere((t) => t.id == id);
    final updated = existing.copyWith(
      name:        name,
      description: description,
      dueDate:     dueDate,
      clearDueDate: dueDate == null,
    );
    await LocalDb.instance.upsertTask(updated);
    await _reload();
    _backgroundSync();
  }

  Future<void> deleteTask(String id) async {
    final existing = _tasks.firstWhere((t) => t.id == id);
    // Soft-delete so it propagates to other devices via sync
    final deleted = existing.copyWith(isDeleted: true);
    await LocalDb.instance.upsertTask(deleted);
    await _reload();
    _backgroundSync();
  }

  Future<void> toggleComplete(String id) async {
    final existing = _tasks.firstWhere((t) => t.id == id);
    final toggled = existing.copyWith(completed: !existing.completed);
    await LocalDb.instance.upsertTask(toggled);
    await _reload();
    _backgroundSync();
  }

  /// Force a manual sync (e.g. pull-to-refresh).
  Future<void> manualSync() => SyncService.instance.sync();

  // ── Preferences ───────────────────────────────────────────────

  Future<void> setSortByDate(bool value) async {
    _sortByDate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortKey, value);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _darkMode = !_darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _darkMode ? 'dark' : 'light');
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _backgroundSync() {
    SyncService.instance.sync().ignore();
  }
}
