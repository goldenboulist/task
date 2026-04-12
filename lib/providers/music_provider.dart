import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/local_db.dart';
import '../services/music_audio_handler.dart';
import '../services/music_sync_service.dart';
import '../services/sync_service.dart' show SyncStatus; // reuse the enum

class MusicProvider extends ChangeNotifier {
  final MusicAudioHandler audioHandler;

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;

  MusicProvider({required this.audioHandler}) {
    // When the player advances a track, repaint the mini-player.
    audioHandler.playingStream.listen((_) => notifyListeners());

    // Persist resolved durations back to the DB + model list.
    audioHandler.onDurationResolved = (songId, ms) async {
      final idx = _songs.indexWhere((s) => s.id == songId);
      if (idx < 0) return;
      _songs[idx].durationMs = ms;
      _songs[idx].updatedAt = DateTime.now().toUtc();
      await LocalDb.instance.upsertSong(_songs[idx]);
      notifyListeners();
    };
  }

  // ── Public state ──────────────────────────────────────────────

  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  SyncStatus get syncStatus => _syncStatus;
  Song? get currentSong => audioHandler.currentSong;
  bool get isPlaying => audioHandler.isPlaying;

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    await MusicSyncService.instance.init();
    await _reload();

    // Initial sync — pulls metadata then files.
    await sync();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        await sync();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    _songs = await LocalDb.instance.getAllSongs();
    _songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _playlists = await LocalDb.instance.getAllPlaylists();
    for (final pl in _playlists) {
      pl.songIds = await LocalDb.instance.getSongIdsForPlaylist(pl.id);
    }
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────

  Future<void> playSong(Song song, {List<Song>? fromQueue}) async {
    final queue = (fromQueue ?? _songs)
        .where((s) => s.hasLocalFile)
        .toList();
    final idx = queue.indexWhere((s) => s.id == song.id);
    if (idx < 0) return;
    await audioHandler.setQueue(queue, startIndex: idx);
    await audioHandler.play();
    notifyListeners();
  }

  Future<void> playPlaylist(Playlist playlist) async {
    final songs = playlist.songIds
        .map((id) {
          final idx = _songs.indexWhere((s) => s.id == id);
          return idx >= 0 ? _songs[idx] : null;
        })
        .whereType<Song>()
        .where((s) => s.hasLocalFile)
        .toList();
    if (songs.isEmpty) return;
    await audioHandler.setQueue(songs);
    await audioHandler.play();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    audioHandler.isPlaying ? await audioHandler.pause() : await audioHandler.play();
    notifyListeners();
  }

  Future<void> skipNext() async {
    await audioHandler.skipToNext();
    notifyListeners();
  }

  Future<void> skipPrevious() async {
    await audioHandler.skipToPrevious();
    notifyListeners();
  }

  // ── Library CRUD ──────────────────────────────────────────────

  /// Opens the file picker, copies the MP3 into app storage, then syncs.
  Future<bool> addSongFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result == null || result.files.isEmpty) return false;

    final picked = result.files.first;
    final srcPath = picked.path;
    if (srcPath == null) return false;

    final dir = await _musicDir();
    final songId = _generateId();
    final destPath = p.join(dir.path, '$songId.mp3');
    await File(srcPath).copy(destPath);

    final title = p.basenameWithoutExtension(picked.name);
    final song = Song(
      id: songId,
      title: title,
      artist: '',
      localPath: destPath,
      synced: false,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await LocalDb.instance.upsertSong(song);
    await _reload();
    _backgroundSync();
    return true;
  }

  Future<void> editSong(
    Song song, {
    required String title,
    required String artist,
  }) async {
    song.title = title.trim();
    song.artist = artist.trim();
    song.synced = false;
    song.updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertSong(song);
    await _reload();
    _backgroundSync();
  }

  Future<void> deleteSong(String songId) async {
    // Remove from all playlists.
    for (final pl in _playlists) {
      if (pl.songIds.contains(songId)) {
        await LocalDb.instance.removeSongFromPlaylist(pl.id, songId);
      }
    }

    // Delete local file.
    final idx = _songs.indexWhere((s) => s.id == songId);
    if (idx >= 0) {
      final path = _songs[idx].localPath;
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }

    await LocalDb.instance.deleteSong(songId);
    await _reload();

    // Tell server to delete too (fire-and-forget).
    MusicSyncService.instance.deleteSong(songId).ignore();
  }

  // ── Playlist CRUD ─────────────────────────────────────────────

  Future<void> createPlaylist(String name) async {
    final pl = Playlist.create(name.trim());
    await LocalDb.instance.upsertPlaylist(pl);
    await _reload();
    _backgroundSync();
  }

  Future<void> renamePlaylist(String id, String name) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _playlists[idx].name = name.trim();
    _playlists[idx].updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    await _reload();
    _backgroundSync();
  }

  Future<void> deletePlaylist(String id) async {
    await LocalDb.instance.deletePlaylist(id);
    await _reload();
    _backgroundSync();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    if (_playlists[idx].songIds.contains(songId)) return;
    await LocalDb.instance.addSongToPlaylist(playlistId, songId);
    _playlists[idx].updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    await _reload();
    _backgroundSync();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await LocalDb.instance.removeSongFromPlaylist(playlistId, songId);
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      _playlists[idx].updatedAt = DateTime.now().toUtc();
      await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    }
    await _reload();
    _backgroundSync();
  }

  // ── Sync ──────────────────────────────────────────────────────

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      // 1. Push local metadata → get server-canonical list.
      final result = await MusicSyncService.instance.pushMetadata(
        songs: _songs,
        playlists: _playlists,
      );

      // 2. Merge server list into local DB (preserve localPath/synced).
      await _mergeFromServer(result);

      // 3. Upload songs that haven't reached the server yet.
      await _uploadPending();

      // 4. Download songs the server has that we don't have locally.
      await _downloadMissing();

      await _reload();
      _syncStatus = SyncStatus.success;
    } catch (_) {
      _syncStatus = SyncStatus.error;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ── Sync helpers ──────────────────────────────────────────────

  Future<void> _mergeFromServer(MusicSyncResult result) async {
    // Build a map of what we currently have locally.
    final existingMap = {for (final s in _songs) s.id: s};

    final merged = result.songs.map((serverSong) {
      final local = existingMap[serverSong.id];
      return Song(
        id: serverSong.id,
        title: serverSong.title,
        artist: serverSong.artist,
        durationMs: local?.durationMs ?? serverSong.durationMs,
        localPath: local?.localPath,
        synced: local?.localPath != null, // true only if we have the file
        createdAt: serverSong.createdAt,
        updatedAt: serverSong.updatedAt,
      );
    }).toList();

    // Delete local files for songs the server no longer has.
    final serverIds = result.songs.map((s) => s.id).toSet();
    for (final s in _songs) {
      if (!serverIds.contains(s.id) && s.localPath != null) {
        final f = File(s.localPath!);
        if (await f.exists()) await f.delete();
      }
    }

    await LocalDb.instance.replaceAllSongs(merged);

    // Merge playlists.
    final mergedPlaylists = result.playlists.map((serverPl) {
      return Playlist(
        id: serverPl.id,
        name: serverPl.name,
        songIds: result.playlistSongs[serverPl.id] ?? [],
        createdAt: serverPl.createdAt,
        updatedAt: serverPl.updatedAt,
      );
    }).toList();

    await LocalDb.instance.replaceAllPlaylists(mergedPlaylists, result.playlistSongs);
  }

  Future<void> _uploadPending() async {
    for (final song in _songs) {
      if (!song.synced && song.localPath != null) {
        try {
          await MusicSyncService.instance.uploadSong(song);
          song.synced = true;
          await LocalDb.instance.upsertSong(song);
        } catch (_) {
          // Will retry on next sync.
        }
      }
    }
  }

  Future<void> _downloadMissing() async {
    final dir = await _musicDir();
    for (final song in _songs) {
      final missing = song.localPath == null ||
          !File(song.localPath!).existsSync();
      if (missing && song.synced) {
        try {
          final destPath = p.join(dir.path, '${song.id}.mp3');
          await MusicSyncService.instance.downloadSong(song.id, destPath);
          song.localPath = destPath;
          await LocalDb.instance.upsertSong(song);
        } catch (_) {
          // Will retry on next sync.
        }
      }
    }
  }

  void _backgroundSync() {
    sync().ignore();
  }

  // ── Utilities ─────────────────────────────────────────────────

  Future<Directory> _musicDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'music'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _generateId() {
    // Simple UUID v4-like ID using Dart's built-in randomness.
    const hex = '0123456789abcdef';
    final buf = StringBuffer();
    final rand = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
      buf.write(hex[(rand >> (i * 2)) & 0xF]);
    }
    return buf.toString();
  }
}
