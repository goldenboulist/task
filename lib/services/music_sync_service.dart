import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';

const String _musicUrl = 'https://maxime-anterion.com/api/music_sync.php';

// ── Result type ───────────────────────────────────────────────

class MusicSyncResult {
  final List<Song> songs;
  final List<Playlist> playlists;
  /// Maps playlist_id → ordered list of song_ids.
  final Map<String, List<String>> playlistSongs;

  const MusicSyncResult(this.songs, this.playlists, this.playlistSongs);
}

// ── Service ───────────────────────────────────────────────────

class MusicSyncService {
  MusicSyncService._();
  static final instance = MusicSyncService._();

  late final String _apiKey;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _apiKey = dotenv.env['API_KEY'] ?? '';
    if (_apiKey.isEmpty) throw Exception('API_KEY missing from .env');
    _ready = true;
  }

  // ── Metadata sync ─────────────────────────────────────────────

  /// Pull server-authoritative metadata (no file transfers).
  Future<MusicSyncResult> pullMetadata() async {
    final body = await _postJson({'action': 'pull_metadata'});
    return _parse(body);
  }

  /// Push all local metadata; server upserts + prunes; returns canonical list.
  Future<MusicSyncResult> pushMetadata({
    required List<Song> songs,
    required List<Playlist> playlists,
  }) async {
    final psRows = <Map<String, String>>[];
    for (final pl in playlists) {
      for (final sid in pl.songIds) {
        psRows.add({'playlist_id': pl.id, 'song_id': sid});
      }
    }
    final body = await _postJson({
      'action': 'push_metadata',
      'songs': songs.map((s) => s.toApiJson()).toList(),
      'playlists': playlists.map((p) => p.toApiJson()).toList(),
      'playlist_songs': psRows,
    });
    return _parse(body);
  }

  // ── File transfers ────────────────────────────────────────────

  /// Upload the MP3 for [song] to the server. Uses multipart POST.
  Future<void> uploadSong(Song song) async {
    if (song.localPath == null) throw Exception('Song has no local file');

    final request = http.MultipartRequest('POST', Uri.parse(_musicUrl));
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.fields['action'] = 'upload';
    request.fields['song_id'] = song.id;
    request.files
        .add(await http.MultipartFile.fromPath('file', song.localPath!));

    final streamed =
        await request.send().timeout(const Duration(seconds: 120));
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw Exception('Upload ${streamed.statusCode}: $body');
    }
  }

  /// Download the MP3 for [songId] and save it to [destPath].
  Future<void> downloadSong(String songId, String destPath) async {
    final response = await http
        .post(
          Uri.parse(_musicUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({'action': 'download', 'song_id': songId}),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Download ${response.statusCode}');
    }

    final file = File(destPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
  }

  /// Tell the server to permanently delete a song's file and record.
  Future<void> deleteSong(String songId) async {
    await _postJson({'action': 'delete_song', 'song_id': songId});
  }

  // ── Helpers ───────────────────────────────────────────────────

  Future<String> _postJson(Map<String, dynamic> payload) async {
    final response = await http
        .post(
          Uri.parse(_musicUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    return response.body;
  }

  MusicSyncResult _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;

    final songs = (json['songs'] as List<dynamic>)
        .map((e) => Song.fromApiJson(e as Map<String, dynamic>))
        .toList();

    final playlists = (json['playlists'] as List<dynamic>)
        .map((e) => Playlist.fromApiJson(e as Map<String, dynamic>))
        .toList();

    final Map<String, List<String>> playlistSongs = {};
    for (final ps in (json['playlist_songs'] as List<dynamic>? ?? [])) {
      final pid = ps['playlist_id'] as String;
      final sid = ps['song_id'] as String;
      playlistSongs.putIfAbsent(pid, () => []).add(sid);
    }

    return MusicSyncResult(songs, playlists, playlistSongs);
  }
}
