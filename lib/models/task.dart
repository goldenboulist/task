import 'dart:convert';

class Task {
  final String id;
  final String name;
  final String description;
  final DateTime? dueDate;
  final bool completed;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.name,
    required this.description,
    this.dueDate,
    required this.completed,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        completed: json['completed'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static List<Task> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Task> tasks) =>
      jsonEncode(tasks.map((t) => t.toJson()).toList());
}
