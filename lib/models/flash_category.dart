class FlashCategory {
  final String id;
  final String name;
  final int colorValue;
  final int cardCount; // populated at query time, not persisted
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlashCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.cardCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  FlashCategory copyWith({String? name, int? colorValue, int? cardCount}) {
    return FlashCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      cardCount: cardCount ?? this.cardCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ── SQLite ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_value': colorValue,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory FlashCategory.fromMap(Map<String, dynamic> map,
          {int cardCount = 0}) =>
      FlashCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        colorValue: map['color_value'] as int,
        cardCount: cardCount,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );

  // ── API ───────────────────────────────────────────────────────
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'name': name,
        // MySQL INT is signed 32-bit (max 2,147,483,647).
        // Flutter color values like 0xFF3571E9 exceed that as unsigned, so
        // we send as signed 32-bit — Color() handles negative ints identically.
        'color_value': colorValue.toSigned(32),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory FlashCategory.fromApiJson(Map<String, dynamic> json) =>
      FlashCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: _parseInt(json['color_value']),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}