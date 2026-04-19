import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/discover_song.dart';

// ── Result type ───────────────────────────────────────────────

class DiscoverResult {
  /// Artists from your library used as seeds.
  final List<String> seedArtists;
  /// Similar artists returned by Last.fm.
  final List<String> similarArtists;
  /// Tracks with 30-sec previews from Deezer.
  final List<DiscoverSong> songs;

  const DiscoverResult({
    required this.seedArtists,
    required this.similarArtists,
    required this.songs,
  });
}

// ── Service ───────────────────────────────────────────────────

class DiscoverService {
  DiscoverService._();
  static final instance = DiscoverService._();

  static const _lastFmBase = 'https://ws.audioscrobbler.com/2.0/';
  static const _deezerBase = 'https://api.deezer.com';

  static const _maxSeeds        = 4; // seed artists taken from library
  static const _similarPerSeed  = 5; // similar artists per seed (Last.fm)
  static const _tracksPerArtist = 5; // top tracks per artist (Deezer)

  // ── Entry point ───────────────────────────────────────────────

  Future<DiscoverResult> discover(List<Song> localSongs) async {
    final apiKey = dotenv.env['LASTFM_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception(
        'LASTFM_API_KEY absent du .env.\n'
        'Clé gratuite sur https://www.last.fm/api\n'
        'Puis ajoute dans .env : LASTFM_API_KEY=ta_clé',
      );
    }

    if (localSongs.isEmpty) {
      throw Exception(
          'Ta bibliothèque est vide — ajoute des chansons d\'abord.');
    }

    // 1. Pick a handful of artists from the library as seeds.
    final seeds = _pickSeeds(localSongs);
    debugPrint('[Discover] Seeds → $seeds');

    // 2. Ask Last.fm who sounds like those artists.
    final similar = await _lastFmSimilar(seeds, apiKey);
    debugPrint('[Discover] Similar artists → $similar');

    if (similar.isEmpty) {
      throw Exception(
        'Last.fm n\'a pas trouvé d\'artistes similaires.\n'
        'Vérifie que les artistes de ta bibliothèque sont bien renseignés.',
      );
    }

    // 3. Fetch Deezer top tracks (with 30 s preview) for each similar artist.
    final localKeys = localSongs
        .map((s) => '${s.title.toLowerCase()}|||${s.artist.toLowerCase()}')
        .toSet();

    final all = <DiscoverSong>[];
    final seenIds = <String>{};

    for (final artist in similar) {
      final tracks = await _deezerTopTracks(artist);
      for (final t in tracks) {
        if (seenIds.contains(t.id)) continue;
        final key =
            '${t.title.toLowerCase()}|||${t.artist.toLowerCase()}';
        if (localKeys.contains(key)) continue; // already in library
        seenIds.add(t.id);
        all.add(t);
      }
    }

    all.shuffle(Random()); // fresh order on each refresh

    return DiscoverResult(
      seedArtists: seeds,
      similarArtists: similar,
      songs: all,
    );
  }

  // ── Seed selection ────────────────────────────────────────────

  List<String> _pickSeeds(List<Song> songs) {
    final artists = songs
        .map((s) => s.artist.trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    if (artists.isEmpty) {
      // No artist metadata — use song titles as a last resort.
      return songs.take(_maxSeeds).map((s) => s.title.trim()).toList();
    }

    artists.shuffle(Random());
    return artists.take(_maxSeeds).toList();
  }

  // ── Last.fm: artist.getSimilar ────────────────────────────────

  Future<List<String>> _lastFmSimilar(
      List<String> seeds, String apiKey) async {
    final seen = <String>{};
    final result = <String>[];

    for (final seed in seeds) {
      try {
        final uri = Uri.parse(_lastFmBase).replace(queryParameters: {
          'method': 'artist.getSimilar',
          'artist': seed,
          'api_key': apiKey,
          'format': 'json',
          'limit': '$_similarPerSeed',
          'autocorrect': '1',
        });

        final res =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final artists =
            (body['similarartists']?['artist'] as List?) ?? [];

        for (final a in artists) {
          final name = (a['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty && !seen.contains(name.toLowerCase())) {
            seen.add(name.toLowerCase());
            result.add(name);
          }
        }
      } catch (e) {
        debugPrint('[Discover] Last.fm error for "$seed": $e');
      }
    }

    return result;
  }

  // ── Deezer: artist search + top tracks ───────────────────────

  Future<List<DiscoverSong>> _deezerTopTracks(String artistName) async {
    try {
      final artistId = await _deezerArtistId(artistName);
      if (artistId == null) return [];

      final uri = Uri.parse(
          '$_deezerBase/artist/$artistId/top?limit=$_tracksPerArtist');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final tracks = (body['data'] as List?) ?? [];

      return tracks
          .map((t) => _toDiscoverSong(t as Map<String, dynamic>))
          .where((s) => s.previewUrl != null && s.previewUrl!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[Discover] Deezer error for "$artistName": $e');
      return [];
    }
  }

  Future<int?> _deezerArtistId(String artistName) async {
    final uri = Uri.parse('$_deezerBase/search/artist')
        .replace(queryParameters: {'q': artistName, 'limit': '1'});
    final res =
        await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['data'] as List?) ?? [];
    if (items.isEmpty) return null;
    return (items.first as Map<String, dynamic>)['id'] as int?;
  }

  DiscoverSong _toDiscoverSong(Map<String, dynamic> track) {
    final artist = track['artist'] as Map<String, dynamic>?;
    final album  = track['album']  as Map<String, dynamic>?;

    // Pick the best available artwork.
    final artwork = (album?['cover_medium'] ??
        album?['cover_small'] ??
        artist?['picture_medium']) as String?;

    return DiscoverSong(
      id:         (track['id'] as int).toString(),
      title:      (track['title'] as String?)  ?? 'Unknown',
      artist:     (artist?['name'] as String?) ?? 'Unknown Artist',
      album:      album?['title']  as String?,
      previewUrl: track['preview'] as String?,
      artworkUrl: artwork,
      genre:      null,
    );
  }
}