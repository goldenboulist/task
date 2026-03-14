import 'dart:convert';

class Task {
  final String id;
  final String name;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.name,
    required this.description,
    this.dueDate,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? name,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? completed,
  }) {
    return Task(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completed: completed ?? this.completed,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ── SQLite ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'due_date': dueDate != null ? '${dueDate!.year.toString().padLeft(4,"0")}-${dueDate!.month.toString().padLeft(2,"0")}-${dueDate!.day.toString().padLeft(2,"0")}' : null,
        'completed': completed ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        completed: (map['completed'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );

  // ── API ───────────────────────────────────────────────────────
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'name': name,
        'description': description,
        'due_date': dueDate != null ? '${dueDate!.year.toString().padLeft(4,"0")}-${dueDate!.month.toString().padLeft(2,"0")}-${dueDate!.day.toString().padLeft(2,"0")}' : null,
        'completed': completed,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory Task.fromApiJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        completed: json['completed'] == true || json['completed'] == 1,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  // ── Legacy migration from SharedPreferences ───────────────────
  factory Task.fromLegacyJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        completed: json['completed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.now(),
      );

  static List<Task> legacyListFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Task.fromLegacyJson(e as Map<String, dynamic>)).toList();
  }
}