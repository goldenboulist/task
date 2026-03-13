import 'dart:convert';

class Task {
  final String id;
  final String name;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final DateTime createdAt;
  // ── Sync fields ──────────────────────────────────────────────
  final DateTime updatedAt;
  final bool synced;
  final bool isDeleted;

  const Task({
    required this.id,
    required this.name,
    required this.description,
    this.dueDate,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
    this.isDeleted = false,
  });

  Task copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    bool? isDeleted,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      // Always bump updatedAt and mark unsynced on any change
      updatedAt: updatedAt ?? DateTime.now(),
      synced: synced ?? false,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // ── SQLite ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'completed': completed ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'synced': synced ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String).toLocal()
            : null,
        completed: (map['completed'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
        synced: (map['synced'] as int) == 1,
        isDeleted: (map['is_deleted'] as int) == 1,
      );

  // ── API (server) ──────────────────────────────────────────────
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'name': name,
        'description': description,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'completed': completed,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted,
      };

  factory Task.fromApiJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String).toLocal()
            : null,
        completed: json['completed'] == true || json['completed'] == 1,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        synced: true,
        isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      );

  // ── Legacy SharedPreferences JSON (for one-time migration) ────
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
        synced: false,
      );

  static List<Task> legacyListFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Task.fromLegacyJson(e as Map<String, dynamic>))
        .toList();
  }
}
