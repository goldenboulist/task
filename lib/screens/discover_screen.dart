import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/discover_song.dart';
import '../providers/discover_provider.dart';
import '../providers/music_provider.dart';

// ══════════════════════════════════════════════════════════════
//  DiscoverTab — embedded in MusicScreen's TabBarView
// ══════════════════════════════════════════════════════════════

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    final discover = context.watch<DiscoverProvider>();
    final music    = context.watch<MusicProvider>();

    return Column(
      children: [
        _Header(discover: discover, music: music),
        Expanded(
          child: switch (discover.status) {
            DiscoverStatus.idle    => _IdleState(
                onDiscover: () => discover.discover(music.songs)),
            DiscoverStatus.loading => const _LoadingState(),
            DiscoverStatus.error   => _ErrorState(
                message: discover.error ?? 'Erreur inconnue',
                onRetry: () => discover.discover(music.songs)),
            DiscoverStatus.loaded  => _SongGrid(
                songs:    discover.suggestions,
                discover: discover,
                music:    music),
          },
        ),
        if (discover.playingId != null) _PreviewBar(discover: discover),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DiscoverProvider discover;
  final MusicProvider music;
  const _Header({required this.discover, required this.music});

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isLoading = discover.status == DiscoverStatus.loading;
    final seeds     = discover.seedArtists;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Seed-artist chips — shown once we have results
              if (seeds.isNotEmpty) ...[
                const Icon(Icons.library_music_outlined, size: 15),
                const SizedBox(width: 6),
                Text('Basé sur :',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: seeds
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  label: Text(a,
                                      style:
                                          const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: cs.secondaryContainer,
                                  labelStyle: TextStyle(
                                      color: cs.onSecondaryContainer),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              const SizedBox(width: 8),

              // Refresh button
              FilledButton.tonalIcon(
                onPressed:
                    isLoading ? null : () => discover.discover(music.songs),
                icon: isLoading
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSecondaryContainer),
                      )
                    : const Icon(Icons.refresh_rounded, size: 17),
                label: Text(isLoading ? 'Chargement…' : 'Refresh'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────

class _IdleState extends StatelessWidget {
  final VoidCallback onDiscover;
  const _IdleState({required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 72, color: cs.primary),
            const SizedBox(height: 20),
            Text('Découvre de nouvelles musiques',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'On analyse ta bibliothèque, on cherche des artistes similaires '
              'via Last.fm, puis on te propose des morceaux à écouter '
              'avec des previews 30 s.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Lancer la découverte'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Recherche d\'artistes similaires…',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text('Last.fm → Deezer previews',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text('Une erreur est survenue',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Song grid ─────────────────────────────────────────────────

class _SongGrid extends StatelessWidget {
  final List<DiscoverSong> songs;
  final DiscoverProvider discover;
  final MusicProvider music;
  const _SongGrid(
      {required this.songs, required this.discover, required this.music});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('Aucune suggestion — réessaie.'),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: songs.length,
      itemBuilder: (ctx, i) =>
          _SongCard(song: songs[i], discover: discover, music: music),
    );
  }
}

// ── Song card ─────────────────────────────────────────────────

class _SongCard extends StatelessWidget {
  final DiscoverSong song;
  final DiscoverProvider discover;
  final MusicProvider music;
  const _SongCard(
      {required this.song, required this.discover, required this.music});

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final isPlaying   = discover.playingId == song.id && discover.isPreviewPlaying;
    final isAdded     = discover.isAdded(song.id);
    final isDling     = discover.isDownloading(song.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isPlaying ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isPlaying
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                song.artworkUrl != null
                    ? Image.network(song.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderArt())
                    : _PlaceholderArt(),
                if (song.previewUrl != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _PlayButton(
                      isPlaying: isPlaying,
                      onTap: () => discover.togglePreview(song),
                    ),
                  ),
              ],
            ),
          ),

          // Metadata + add button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: isAdded
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: cs.primary),
                            const SizedBox(width: 4),
                            Text('Ajouté',
                                style: TextStyle(
                                    fontSize: 12, color: cs.primary)),
                          ],
                        )
                      : isDling
                          ? const Center(
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _showDialog(context),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Ajouter',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context) => showDialog(
        context: context,
        builder: (_) => _AddDialog(
            song: song, discover: discover, music: music),
      );
}

// ── Play button overlay ───────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color:
              isPlaying ? cs.primary : cs.surface.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 22,
          color: isPlaying ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}

// ── Placeholder artwork ───────────────────────────────────────

class _PlaceholderArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.music_note_rounded,
            size: 40, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ── Preview mini-bar ──────────────────────────────────────────

class _PreviewBar extends StatelessWidget {
  final DiscoverProvider discover;
  const _PreviewBar({required this.discover});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final song = discover.suggestions
        .where((s) => s.id == discover.playingId)
        .firstOrNull;
    if (song == null) return const SizedBox.shrink();

    return Container(
      color: cs.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: song.artworkUrl != null
                ? Image.network(song.artworkUrl!,
                    width: 40, height: 40, fit: BoxFit.cover)
                : Container(
                    width: 40,
                    height: 40,
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded, size: 20)),
          ),
          const SizedBox(width: 12),

          // Title / artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),

          // Preview badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('30 s',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),

          IconButton(
            icon: Icon(discover.isPreviewPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
            onPressed: () => discover.togglePreview(song),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => discover.stopPreview(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Add-to-library dialog
// ══════════════════════════════════════════════════════════════

class _AddDialog extends StatefulWidget {
  final DiscoverSong song;
  final DiscoverProvider discover;
  final MusicProvider music;
  const _AddDialog(
      {required this.song, required this.discover, required this.music});

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  bool    _adding  = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final song = widget.song;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: song.artworkUrl != null
                ? Image.network(song.artworkUrl!,
                    width: 120, height: 120, fit: BoxFit.cover)
                : Container(
                    width: 120,
                    height: 120,
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded, size: 48)),
          ),
          const SizedBox(height: 16),

          // Song info
          Text(song.title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(song.artist,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          if (song.album != null) ...[
            const SizedBox(height: 2),
            Text(song.album!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12)),
          ],
          const SizedBox(height: 14),

          // Info banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On va essayer de récupérer la chanson complète via YouTube. Si introuvable, un preview 30 secondes sera sauvegardé.',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 12),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _adding ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _adding ? null : _add,
          icon: _adding
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.onPrimary))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_adding ? 'Téléchargement…' : 'Ajouter à la bibliothèque'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    setState(() {
      _adding = true;
      _error  = null;
    });
    try {
      await widget.discover.addToLibrary(widget.song, widget.music);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _adding = false; });
    }
  }
}