import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/discover_song.dart';
import '../providers/music_provider.dart';
import '../services/discover_service.dart';
import 'package:flutter/services.dart' show rootBundle;

enum DiscoverStatus { idle, loading, loaded, error }

class DiscoverProvider extends ChangeNotifier {
  // Dedicated player for 30-sec Deezer previews — never touches
  // the main MusicAudioHandler so playback isn't interrupted.
  final _previewPlayer = AudioPlayer();

  // ── State ──────────────────────────────────────────────────────
  DiscoverStatus _status = DiscoverStatus.idle;
  List<String> _seedArtists   = [];
  List<String> _similarArtists = [];
  List<DiscoverSong> _suggestions = [];
  String? _playingId;
  bool   _isPreviewPlaying = false;
  String? _error;

  final Set<String> _downloading = {};
  final Set<String> _addedIds    = {};

  // ── Getters ────────────────────────────────────────────────────
  DiscoverStatus    get status          => _status;
  List<String>      get seedArtists     => _seedArtists;
  List<String>      get similarArtists  => _similarArtists;
  List<DiscoverSong> get suggestions    => _suggestions;
  String?           get playingId       => _playingId;
  bool              get isPreviewPlaying => _isPreviewPlaying;
  String?           get error           => _error;
  bool isDownloading(String id) => _downloading.contains(id);
  bool isAdded(String id)       => _addedIds.contains(id);

  DiscoverProvider(MusicProvider musicProvider) {
    // Mirror the main player volume onto the preview player so the
    // existing volume control applies to previews too.
    _previewPlayer.setVolume(musicProvider.volume);
    musicProvider.audioHandler.volumeStream.listen((vol) {
      _previewPlayer.setVolume(vol);
    });

    _previewPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPreviewPlaying = false;
        notifyListeners();
      }
    });
  }

  // ── Discover ───────────────────────────────────────────────────

  Future<void> discover(List<Song> localSongs) async {
    if (_status == DiscoverStatus.loading) return;

    await _stopPreview();
    _status       = DiscoverStatus.loading;
    _seedArtists  = [];
    _similarArtists = [];
    _suggestions  = [];
    _error        = null;
    _addedIds.clear();
    notifyListeners();

    try {
      final result = await DiscoverService.instance.discover(localSongs);
      _seedArtists    = result.seedArtists;
      _similarArtists = result.similarArtists;
      _suggestions    = result.songs;
      _status         = DiscoverStatus.loaded;
    } catch (e) {
      _error  = e.toString();
      _status = DiscoverStatus.error;
      debugPrint('[DiscoverProvider] $e');
    }
    notifyListeners();
  }

  // ── Preview playback ───────────────────────────────────────────

  Future<void> togglePreview(DiscoverSong song) async {
    if (song.previewUrl == null) return;

    if (_playingId == song.id) {
      if (_isPreviewPlaying) {
        await _previewPlayer.pause();
        _isPreviewPlaying = false;
      } else {
        await _previewPlayer.play();
        _isPreviewPlaying = true;
      }
      notifyListeners();
      return;
    }

    _playingId        = song.id;
    _isPreviewPlaying = true;
    notifyListeners();

    try {
      await _previewPlayer.setUrl(song.previewUrl!);
      await _previewPlayer.play();
    } catch (e) {
      _isPreviewPlaying = false;
      debugPrint('[DiscoverProvider] Preview error: $e');
      notifyListeners();
    }
  }

  Future<void> stopPreview() async {
    await _stopPreview();
    notifyListeners();
  }

  Future<void> _stopPreview() async {
    await _previewPlayer.stop();
    _playingId        = null;
    _isPreviewPlaying = false;
  }

  // ── Add to library ────────────────────────────────────────────

  /// Tries to download the full song via YouTube; falls back to the 30 s
  /// Deezer preview if the search fails, times out, or returns nothing.
  Future<void> addToLibrary(
      DiscoverSong discoverSong, MusicProvider musicProvider) async {
    if (_addedIds.contains(discoverSong.id)) return;

    _downloading.add(discoverSong.id);
    notifyListeners();

    String? lastError;

    try {
      final base = await getApplicationDocumentsDirectory();
      final dir  = Directory(p.join(base.path, 'music'));
      if (!await dir.exists()) await dir.create(recursive: true);

      final songId   = _newId();
      String? destPath;
      bool    fullSong = false;

      // ── 1. Try yt-dlp (full song) ──────────────────────────────
      try {
        // Extract yt-dlp binary from assets on first run
        final ytDlpPath = await _ensureYtDlp();
        debugPrint('[DiscoverProvider] yt-dlp path: $ytDlpPath');

        final query    = '${discoverSong.title} ${discoverSong.artist}';
        final outTmpl  = p.join(dir.path, '$songId.%(ext)s');

        debugPrint('[DiscoverProvider] yt-dlp searching: $query');

        final result = await Process.run(
          ytDlpPath,
          [
            'ytsearch1:$query',        // search YouTube, take first result
            '--extract-audio',
            '--audio-format', 'mp3',
            '--audio-quality', '0',    // best quality
            '--output', outTmpl,
            '--no-playlist',
            '--no-warnings',
            '--quiet',
            '--no-progress',
          ],
          runInShell: false,
        ).timeout(const Duration(minutes: 3));

        debugPrint('[DiscoverProvider] yt-dlp exit: ${result.exitCode}');
        if (result.stderr.toString().isNotEmpty) {
          debugPrint('[DiscoverProvider] yt-dlp stderr: ${result.stderr}');
        }

        if (result.exitCode == 0) {
          // yt-dlp always outputs .mp3 because of --audio-format mp3
          final candidate = File(p.join(dir.path, '$songId.mp3'));
          if (await candidate.exists()) {
            destPath = candidate.path;
            fullSong = true;
            debugPrint('[DiscoverProvider] yt-dlp saved: $destPath');
          } else {
            throw Exception('yt-dlp succeeded but output file not found');
          }
        } else {
          throw Exception('yt-dlp exit ${result.exitCode}: ${result.stderr}');
        }
      } catch (e) {
        debugPrint('[DiscoverProvider] yt-dlp failed, trying preview: $e');
        lastError = e.toString();
        destPath  = null;
      }

      // ── 2. Fallback: 30s Deezer preview ────────────────────────
      if (!fullSong) {
        debugPrint('[DiscoverProvider] Trying Deezer preview…');

        if (discoverSong.previewUrl == null) {
          throw Exception(
            'Aucun audio disponible pour "${discoverSong.title}".'
            '${lastError != null ? '\nyt-dlp: $lastError' : ''}',
          );
        }

        final response = await http
            .get(Uri.parse(discoverSong.previewUrl!))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw Exception('Preview HTTP ${response.statusCode}');
        }
        if (response.bodyBytes.isEmpty) {
          throw Exception('Preview vide reçue.');
        }

        destPath = p.join(dir.path, '$songId.mp3');
        await File(destPath).writeAsBytes(response.bodyBytes);
        debugPrint('[DiscoverProvider] Preview saved: $destPath');
      }

      final song = Song(
        id:        songId,
        title:     discoverSong.title,
        artist:    discoverSong.artist,
        localPath: destPath!,
        synced:    false,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await musicProvider.addDiscoveredSong(song);
      _addedIds.add(discoverSong.id);

    } catch (e, st) {
      debugPrint('[DiscoverProvider] addToLibrary FAILED: $e');
      debugPrint('[DiscoverProvider] Stack: $st');
      rethrow;
    } finally {
      _downloading.remove(discoverSong.id);
      notifyListeners();
    }
  }

  // ── Extracts yt-dlp.exe from assets to a writable location ──────────
  Future<String> _ensureYtDlp() async {
    final base    = await getApplicationDocumentsDirectory();
    final ytDlp   = File(p.join(base.path, 'yt-dlp.exe'));

    if (!await ytDlp.exists()) {
      debugPrint('[DiscoverProvider] Extracting yt-dlp from assets…');
      final data = await rootBundle.load('assets/bin/yt-dlp.exe');
      await ytDlp.writeAsBytes(data.buffer.asUint8List());
      debugPrint('[DiscoverProvider] yt-dlp extracted to: ${ytDlp.path}');
    }

    return ytDlp.path;
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _newId() {
    const hex = '0123456789abcdef';
    final buf  = StringBuffer();
    final rand = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
      buf.write(hex[(rand >> (i * 2)) & 0xF]);
    }
    return buf.toString();
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }
}