import 'dart:io';
import 'dart:async';
import 'dart:math';
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
import '../services/sync_service.dart' show SyncStatus;

class MusicProvider extends ChangeNotifier {
  final MusicAudioHandler audioHandler;

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _isSyncing = false;
  bool _isShuffled = false;
  StreamSubscription? _connectivitySub;

  MusicProvider({required this.audioHandler}) {
    audioHandler.playingStream.listen((_) => notifyListeners());
    audioHandler.mediaItem.listen((_) => notifyListeners());
    audioHandler.volumeStream.listen((_) => notifyListeners());

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
  bool get isShuffled => _isShuffled;
  double get volume => audioHandler.volume;

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      await MusicSyncService.instance.init();
    } catch (e) {
      debugPrint('MusicSyncService init failed (offline / missing key?): $e');
    }
    await _reload();
    // On startup, pull from server to get the latest state.
    await sync();

    // Load persisted volume.
    final savedVolume = await LocalDb.instance.getSetting('music_volume');
    if (savedVolume != null) {
      final vol = double.tryParse(savedVolume);
      if (vol != null) await audioHandler.setVolume(vol);
    }

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
    _songs.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _playlists = await LocalDb.instance.getAllPlaylists();
    for (final pl in _playlists) {
      pl.songIds = await LocalDb.instance.getSongIdsForPlaylist(pl.id);
    }
    notifyListeners();
  }

  // ── Shuffle ───────────────────────────────────────────────────

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    notifyListeners();
  }

  List<Song> _maybeShuffled(List<Song> queue, String startId) {
    if (!_isShuffled) return queue;
    final list = List<Song>.from(queue);
    final currentIdx = list.indexWhere((s) => s.id == startId);
    final current = currentIdx >= 0 ? list.removeAt(currentIdx) : null;
    list.shuffle(Random());
    if (current != null) list.insert(0, current);
    return list;
  }

  Future<void> addDiscoveredSong(Song song) async {
    await LocalDb.instance.upsertSong(song);
    await _reload();
    _pushInBackground();
  }
  // ── Playback ──────────────────────────────────────────────────

  Future<void> playSong(Song song, {List<Song>? fromQueue}) async {
    final raw =
        (fromQueue ?? _songs).where((s) => s.hasLocalFile).toList();
    final queue = _maybeShuffled(raw, song.id);
    final idx = queue.indexWhere((s) => s.id == song.id);
    if (idx < 0) return;
    await audioHandler.setQueue(queue, startIndex: idx);
    await audioHandler.play();
    notifyListeners();
  }

  Future<void> playPlaylist(Playlist playlist) async {
    final raw = playlist.songIds
        .map((id) {
          final idx = _songs.indexWhere((s) => s.id == id);
          return idx >= 0 ? _songs[idx] : null;
        })
        .whereType<Song>()
        .where((s) => s.hasLocalFile)
        .toList();
    if (raw.isEmpty) return;
    final queue =
        _isShuffled ? (List<Song>.from(raw)..shuffle(Random())) : raw;
    await audioHandler.setQueue(queue);
    await audioHandler.play();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    audioHandler.isPlaying
        ? await audioHandler.pause()
        : await audioHandler.play();
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

  Future<void> setVolume(double volume) async {
    await audioHandler.setVolume(volume);
    await LocalDb.instance.saveSetting('music_volume', volume.toString());
    notifyListeners();
  }

  // ── Library CRUD ──────────────────────────────────────────────

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
    // Push: new song goes to server, MP3 gets uploaded.
    _pushInBackground();
    return true;
  }

  Future<void> editSong(Song song,
      {required String title, required String artist}) async {
    song.title = title.trim();
    song.artist = artist.trim();
    song.synced = false;
    song.updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertSong(song);
    await _reload();
    // Push: updated metadata goes to server.
    _pushInBackground();
  }

  Future<void> deleteSong(String songId) async {
    // Remove from all playlists locally.
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

    // Push: tell server to delete the song file + record (fire-and-forget).
    MusicSyncService.instance.deleteSong(songId).ignore();
  }

  // ── Playlist CRUD ─────────────────────────────────────────────

  Future<void> createPlaylist(String name) async {
    final pl = Playlist.create(name.trim());
    await LocalDb.instance.upsertPlaylist(pl);
    await _reload();
    _pushInBackground();
  }

  Future<void> renamePlaylist(String id, String name) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _playlists[idx].name = name.trim();
    _playlists[idx].updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    await _reload();
    _pushInBackground();
  }

  Future<void> deletePlaylist(String id) async {
    await LocalDb.instance.deletePlaylist(id);
    await _reload();
    _pushInBackground();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    if (_playlists[idx].songIds.contains(songId)) return;
    await LocalDb.instance.addSongToPlaylist(playlistId, songId);
    _playlists[idx].updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    await _reload();
    _pushInBackground();
  }

  Future<void> addSongsToPlaylist(
      String playlistId, List<String> songIds) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    for (final songId in songIds) {
      if (!_playlists[idx].songIds.contains(songId)) {
        await LocalDb.instance.addSongToPlaylist(playlistId, songId);
      }
    }
    _playlists[idx].updatedAt = DateTime.now().toUtc();
    await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    await _reload();
    _pushInBackground();
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songId) async {
    await LocalDb.instance.removeSongFromPlaylist(playlistId, songId);
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      _playlists[idx].updatedAt = DateTime.now().toUtc();
      await LocalDb.instance.upsertPlaylist(_playlists[idx]);
    }
    await _reload();
    _pushInBackground();
  }

  // ══════════════════════════════════════════════════════════════
  //  PULL  (git pull) — sync button + on connectivity restore
  //
  //  Fetches the server's authoritative state and replaces local
  //  metadata. Downloads any MP3 files we are missing.
  //  Does NOT send any local data to the server.
  // ══════════════════════════════════════════════════════════════

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      // 1. Fetch server's canonical metadata (read-only).
      final result = await MusicSyncService.instance.pullMetadata();

      // 2. Replace local DB with server data (keeps local file paths).
      await _applyServerState(result);

      // 3. Reload so _songs reflects the freshly-written DB rows —
      //    new server songs (localPath=null, synced=true) are now in the list.
      await _reload();

      // 4. Download MP3 files we don't have yet.
      await _downloadMissing();

      // 5. Reload again to pick up the localPaths set by the downloads.
      await _reload();
      _syncStatus = SyncStatus.success;
    } catch (e) {
      debugPrint('Pull failed: $e');
      _syncStatus = SyncStatus.error;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PUSH  (git push) — called after every local mutation
  //
  //  Sends the full local metadata snapshot to the server so it
  //  matches what the user has on this device. Also uploads any
  //  MP3 files that haven't reached the server yet.
  //  Does NOT touch local data.
  // ══════════════════════════════════════════════════════════════

  Future<void> _push() async {
    // Reload first so we send the freshest snapshot.
    final songs = await LocalDb.instance.getAllSongs();
    final playlists = await LocalDb.instance.getAllPlaylists();
    for (final pl in playlists) {
      pl.songIds = await LocalDb.instance.getSongIdsForPlaylist(pl.id);
    }

    await MusicSyncService.instance
        .pushMetadata(songs: songs, playlists: playlists);

    await _uploadPending();
  }

  /// Fire-and-forget wrapper — mutations call this and move on.
  void _pushInBackground() {
    _push().catchError(
      (e) => debugPrint('Push failed (will retry on next sync): $e'),
    );
  }

  // ── Apply server state ────────────────────────────────────────

  /// Replaces local DB metadata with the server's canonical list.
  /// Preserves [localPath] and [synced] for songs we already have.
  Future<void> _applyServerState(MusicSyncResult result) async {
    final existingMap = {for (final s in _songs) s.id: s};

    final merged = result.songs.map((serverSong) {
      final local = existingMap[serverSong.id];
      return Song(
        id: serverSong.id,
        title: serverSong.title,
        artist: serverSong.artist,
        durationMs: local?.durationMs ?? serverSong.durationMs,
        localPath: local?.localPath,
        // If we already have the song locally, keep its real synced status
        // (false = upload still pending, true = server confirmed).
        // If this song is new from the server, synced = true because the
        // server is the one telling us it exists — _downloadMissing will
        // then fetch the file.
        synced: local != null ? local.synced : true,
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

    final mergedPlaylists = result.playlists.map((serverPl) {
      return Playlist(
        id: serverPl.id,
        name: serverPl.name,
        songIds: result.playlistSongs[serverPl.id] ?? [],
        createdAt: serverPl.createdAt,
        updatedAt: serverPl.updatedAt,
      );
    }).toList();

    await LocalDb.instance.replaceAllPlaylists(
        mergedPlaylists, result.playlistSongs);
  }

  // ── File helpers ──────────────────────────────────────────────

  Future<void> _uploadPending() async {
    for (final song in _songs) {
      if (!song.synced && song.localPath != null) {
        try {
          await MusicSyncService.instance.uploadSong(song);
          song.synced = true;
          await LocalDb.instance.upsertSong(song);
        } catch (_) {
          // Will be retried on the next push.
        }
      }
    }
  }

  Future<void> _downloadMissing() async {
    final dir = await _musicDir();
    for (final song in _songs) {
      final missing =
          song.localPath == null || !File(song.localPath!).existsSync();
      if (missing && song.synced) {
        try {
          final destPath = p.join(dir.path, '${song.id}.mp3');
          await MusicSyncService.instance.downloadSong(song.id, destPath);
          song.localPath = destPath;
          await LocalDb.instance.upsertSong(song);
        } catch (_) {
          // Will be retried on the next pull.
        }
      }
    }
  }

  // ── Utilities ─────────────────────────────────────────────────

  Future<Directory> _musicDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'music'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _generateId() {
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