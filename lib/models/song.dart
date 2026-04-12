import 'package:uuid/uuid.dart';

class Song {
  final String id;
  String title;
  String artist;
  int durationMs; // 0 until resolved from player
  String? localPath; // null = not yet downloaded
  bool synced; // true = MP3 exists on server
  final DateTime createdAt;
  DateTime updatedAt;

  Song({
    required this.id,
    required this.title,
    this.artist = '',
    this.durationMs = 0,
    this.localPath,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Song.create({
    required String title,
    String artist = '',
    String? localPath,
  }) {
    final now = DateTime.now().toUtc();
    return Song(
      id: const Uuid().v4(),
      title: title,
      artist: artist,
      localPath: localPath,
      synced: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: (map['artist'] as String?) ?? '',
        durationMs: (map['duration_ms'] as int?) ?? 0,
        localPath: map['local_path'] as String?,
        synced: ((map['synced'] as int?) ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration_ms': durationMs,
        'local_path': localPath,
        'synced': synced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Song.fromApiJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: (json['artist'] as String?) ?? '',
        durationMs: (json['duration_ms'] as int?) ?? 0,
        synced: true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration_ms': durationMs,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get displayDuration {
    if (durationMs <= 0) return '--:--';
    final s = durationMs ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  bool get hasLocalFile => localPath != null;
}
