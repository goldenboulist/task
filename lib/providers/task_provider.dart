import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

const _storageKey = 'task-manager-tasks';
const _themeKey = 'theme';
const _sortKey = 'sortByDate';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _sortByDate = true;
  bool _darkMode = false;
  bool _initialized = false;

  bool get sortByDate => _sortByDate;
  bool get darkMode => _darkMode;
  bool get initialized => _initialized;

  int get totalTasks => _tasks.length;
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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _tasks = Task.listFromJson(raw);
      } catch (_) {
        _tasks = [];
      }
    }
    _darkMode = prefs.getString(_themeKey) == 'dark';
    _sortByDate = prefs.getBool(_sortKey) ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, Task.listToJson(_tasks));
  }

  void addTask(String name, String description, DateTime? dueDate) {
    _tasks.add(Task(
      id: const Uuid().v4(),
      name: name,
      description: description,
      dueDate: dueDate,
      completed: false,
      createdAt: DateTime.now(),
    ));
    _save();
    notifyListeners();
  }

  void editTask(
      String id, String name, String description, DateTime? dueDate) {
    _tasks = _tasks.map((t) {
      if (t.id == id) {
        return t.copyWith(
          name: name,
          description: description,
          dueDate: dueDate,
          clearDueDate: dueDate == null,
        );
      }
      return t;
    }).toList();
    _save();
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void toggleComplete(String id) {
    _tasks = _tasks
        .map((t) => t.id == id ? t.copyWith(completed: !t.completed) : t)
        .toList();
    _save();
    notifyListeners();
  }

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
}
