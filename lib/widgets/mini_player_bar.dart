import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final song = music.currentSong;
    if (song == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Thin progress bar ────────────────────────────────
        StreamBuilder<Duration>(
          stream: music.audioHandler.positionStream,
          builder: (_, posSnap) {
            return StreamBuilder<Duration?>(
              stream: music.audioHandler.durationStream,
              builder: (_, durSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final dur = durSnap.data ?? Duration.zero;
                final progress =
                    dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.outline,
                    thumbColor: cs.primary,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      if (dur.inMilliseconds > 0) {
                        music.audioHandler.seek(
                          Duration(milliseconds: (v * dur.inMilliseconds).round()),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),

        // ── Controls row ─────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF14181F) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              // Album art placeholder
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.music_note_rounded,
                    color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),

              // Title + artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (song.artist.isNotEmpty)
                      Text(
                        song.artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 28,
                onPressed: music.skipPrevious,
                color: cs.onSurface,
              ),

              // Play / Pause
              StreamBuilder<bool>(
                stream: music.audioHandler.playingStream,
                builder: (_, snap) {
                  final playing = snap.data ?? false;
                  return StreamBuilder<ProcessingState>(
                    stream: music.audioHandler.processingStateStream,
                    builder: (_, stateSnap) {
                      final loading = stateSnap.data == ProcessingState.loading ||
                          stateSnap.data == ProcessingState.buffering;
                      if (loading) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                        ),
                        iconSize: 38,
                        color: cs.primary,
                        onPressed: music.togglePlay,
                      );
                    },
                  );
                },
              ),

              // Next
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 28,
                onPressed: music.skipNext,
                color: cs.onSurface,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
