class FlashCard {
  final String id;
  final String categoryId;
  final String front;
  final String back;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlashCard({
    required this.id,
    required this.categoryId,
    required this.front,
    required this.back,
    required this.createdAt,
    required this.updatedAt,
  });

  FlashCard copyWith({String? front, String? back}) {
    return FlashCard(
      id: id,
      categoryId: categoryId,
      front: front ?? this.front,
      back: back ?? this.back,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ── SQLite ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'front': front,
        'back': back,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory FlashCard.fromMap(Map<String, dynamic> map) => FlashCard(
        id: map['id'] as String,
        categoryId: map['category_id'] as String,
        front: map['front'] as String,
        back: map['back'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );

  // ── API ───────────────────────────────────────────────────────
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'category_id': categoryId,
        'front': front,
        'back': back,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory FlashCard.fromApiJson(Map<String, dynamic> json) => FlashCard(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );
}
