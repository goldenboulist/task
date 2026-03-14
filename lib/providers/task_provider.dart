import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

const _themeKey  = 'theme';
const _sortKey   = 'sortByDate';
const _legacyKey = 'task-manager-tasks'; // one-time migration

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _sortByDate  = true;
  bool _darkMode    = false;
  bool _initialized = false;

  bool get sortByDate  => _sortByDate;
  bool get darkMode    => _darkMode;
  bool get initialized => _initialized;
  SyncStatus get syncStatus => SyncService.instance.status;

  int get totalTasks     => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.completed).length;

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

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode   = prefs.getString(_themeKey) == 'dark';
    _sortByDate = prefs.getBool(_sortKey) ?? true;

    // One-time migration from SharedPreferences → SQLite
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        for (final t in Task.legacyListFromJson(legacy)) {
          await LocalDb.instance.upsertTask(t);
        }
      } catch (_) {}
      await prefs.remove(_legacyKey);
    }

    await _reload();
    
    // Refresh UI whenever a sync completes
    SyncService.instance.statusStream.listen((status) async {
      if (status == SyncStatus.success) {
        await _reload();
      }
      notifyListeners();
    });

    await SyncService.instance.init();

    _initialized = true;
    notifyListeners();
  }

  Future<void> _reload() async {
    _tasks = await LocalDb.instance.getAllActiveTasks();
    notifyListeners();
  }

  // ── CRUD — write locally first, then sync ─────────────────────

  Future<void> addTask(String name, String description, DateTime? dueDate) async {
    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      name: name,
      description: description,
      dueDate: dueDate,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
    await LocalDb.instance.upsertTask(task);
    await _reload();
    _backgroundSync();
  }

  Future<void> editTask(String id, String name, String description, DateTime? dueDate) async {
    final existing = _tasks.firstWhere((t) => t.id == id);
    final updated = existing.copyWith(
      name: name,
      description: description,
      dueDate: dueDate,
      clearDueDate: dueDate == null,
    );
    await LocalDb.instance.upsertTask(updated);
    await _reload();
    _backgroundSync();
  }

  Future<void> deleteTask(String id) async {
    await LocalDb.instance.deleteTask(id);
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

  Future<void> manualSync() => SyncService.instance.pull();

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

  void _backgroundSync() {
    SyncService.instance.push().ignore();
  }
}