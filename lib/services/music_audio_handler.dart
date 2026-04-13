import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';

/// Initialise and return the singleton audio handler.
/// Call this once in main() before runApp().
Future<MusicAudioHandler> initAudioHandler() async {
  return AudioService.init(
    builder: () => MusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yourapp.music',
      androidNotificationChannelName: 'Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF3571E9),
    ),
  );
}

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  List<Song> _queue = [];
  int _currentIndex = -1;

  /// Called by MusicProvider so it can persist resolved durations.
  void Function(String songId, int durationMs)? onDurationResolved;

  MusicAudioHandler() {
    // Forward playback events to audio_service's playbackState stream.
    _player.playbackEventStream.listen((event) {
      playbackState.add(_buildState(event));
    });

    // Auto-advance queue on track completion.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  // ── Public getters ────────────────────────────────────────────

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  int get currentIndex => _currentIndex;
  List<Song> get songQueue => List.unmodifiable(_queue);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  double get volume => _player.volume;
  Stream<double> get volumeStream => _player.volumeStream;

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Queue management ──────────────────────────────────────────

  /// Replace the current queue and start at [startIndex].
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List.of(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final song = currentSong;
    if (song == null) return;

    final path = song.localPath;
    if (path == null || !File(path).existsSync()) return;

    // Broadcast metadata for lock-screen / notification.
    mediaItem.add(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
      duration:
          song.durationMs > 0 ? Duration(milliseconds: song.durationMs) : null,
    ));

    await _player.setFilePath(path);

    // Resolve duration once the player has it.
    final resolved = _player.duration;
    if (resolved != null && resolved.inMilliseconds > 0 && song.durationMs == 0) {
      onDurationResolved?.call(song.id, resolved.inMilliseconds);
    }
  }

  // ── BaseAudioHandler overrides ────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _loadCurrent();
    await play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    // If more than 3 s in, restart the current track.
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      await _loadCurrent();
      await play();
    }
  }

  @override
  Future<void> onTaskRemoved() => stop();

  // ── Private helpers ───────────────────────────────────────────

  PlaybackState _buildState(PlaybackEvent event) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      );
}