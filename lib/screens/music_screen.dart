import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../services/sync_service.dart' show SyncStatus;

// ══════════════════════════════════════════════════════════════
//  MusicScreen
// ══════════════════════════════════════════════════════════════

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Music',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          titleSpacing: 16,
          actions: [_SyncButton()],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.library_music_outlined), text: 'Library'),
              Tab(icon: Icon(Icons.queue_music_rounded), text: 'Playlists'),
            ],
            labelStyle:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        body: const TabBarView(
          children: [
            _LibraryTab(),
            _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Sync button ───────────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = context.watch<MusicProvider>().syncStatus;
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      SyncStatus.syncing => const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      SyncStatus.error => IconButton(
          tooltip: 'Sync failed — tap to retry',
          icon: Icon(Icons.sync_problem_outlined, color: cs.error),
          onPressed: () => context.read<MusicProvider>().sync(),
        ),
      _ => IconButton(
          tooltip: 'Sync now',
          icon: Icon(Icons.sync_outlined, color: cs.onSurfaceVariant),
          onPressed: () => context.read<MusicProvider>().sync(),
        ),
    };
  }
}

// ══════════════════════════════════════════════════════════════
//  Library tab
// ══════════════════════════════════════════════════════════════

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final songs = music.songs;

    return Stack(
      children: [
        songs.isEmpty
            ? _EmptySongs(onAdd: () => _addSong(context))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: songs.length,
                itemBuilder: (context, i) =>
                    _SongTile(song: songs[i], allSongs: songs),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addSong',
            onPressed: () => _addSong(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Song'),
          ),
        ),
      ],
    );
  }

  Future<void> _addSong(BuildContext context) async {
    final ok = await context.read<MusicProvider>().addSongFromFile();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
    }
  }
}

// ── Song tile ─────────────────────────────────────────────────

class _SongTile extends StatelessWidget {
  final Song song;
  final List<Song> allSongs;
  const _SongTile({required this.song, required this.allSongs});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isCurrent = music.currentSong?.id == song.id;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCurrent
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isCurrent && music.isPlaying
              ? Icons.graphic_eq_rounded
              : Icons.music_note_rounded,
          color: isCurrent ? cs.primary : cs.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        song.title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          color: isCurrent ? cs.primary : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Duration / sync indicator
          if (!song.synced)
            Tooltip(
              message: 'Uploading…',
              child: Icon(Icons.cloud_upload_outlined,
                  size: 16, color: cs.onSurfaceVariant),
            )
          else
            Text(
              song.displayDuration,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(width: 4),
          _SongMenu(song: song),
        ],
      ),
      onTap: song.hasLocalFile
          ? () => music.playSong(song, fromQueue: allSongs)
          : null,
    );
  }
}

// ── Song context menu ─────────────────────────────────────────

class _SongMenu extends StatelessWidget {
  final Song song;
  const _SongMenu({required this.song});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit info')),
        PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
        PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _showEditDialog(context);
          case 'playlist':
            _showAddToPlaylistDialog(context);
          case 'delete':
            _showDeleteConfirm(context);
        }
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit song info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<MusicProvider>().editSong(
                    song,
                    title: titleCtrl.text.trim().isEmpty
                        ? song.title
                        : titleCtrl.text,
                    artist: artistCtrl.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    final playlists = context.read<MusicProvider>().playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a playlist first')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Add to playlist'),
        children: playlists.map((pl) {
          final alreadyIn = pl.songIds.contains(song.id);
          return SimpleDialogOption(
            onPressed: alreadyIn
                ? null
                : () {
                    context
                        .read<MusicProvider>()
                        .addSongToPlaylist(pl.id, song.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to "${pl.name}"')),
                    );
                  },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pl.name),
              trailing: alreadyIn
                  ? const Icon(Icons.check, size: 18, color: Colors.grey)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text(
            '"${song.title}" will be removed from your library and the server.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context.read<MusicProvider>().deleteSong(song.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (library) ─────────────────────────────────────

class _EmptySongs extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySongs({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.library_music_outlined,
                size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('No songs yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap "Add Song" to import an MP3',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Playlists tab
// ══════════════════════════════════════════════════════════════

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final playlists = music.playlists;

    return Stack(
      children: [
        playlists.isEmpty
            ? _EmptyPlaylists(onCreate: () => _showCreateDialog(context))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: playlists.length,
                itemBuilder: (context, i) =>
                    _PlaylistTile(playlist: playlists[i]),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'createPlaylist',
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Playlist'),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<MusicProvider>()
                    .createPlaylist(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ── Playlist tile ─────────────────────────────────────────────

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = playlist.songIds.length;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.queue_music_rounded, color: cs.primary, size: 22),
      ),
      title: Text(playlist.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$count song${count == 1 ? '' : 's'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded, size: 26),
            color: cs.primary,
            onPressed: () =>
                context.read<MusicProvider>().playPlaylist(playlist),
            tooltip: 'Play',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('View songs')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
            onSelected: (action) {
              switch (action) {
                case 'open':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailScreen(playlist: playlist),
                    ),
                  );
                case 'rename':
                  _showRenameDialog(context);
                case 'delete':
                  _showDeleteConfirm(context);
              }
            },
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist)),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<MusicProvider>()
                    .renamePlaylist(playlist.id, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete playlist?'),
        content:
            Text('The playlist "${playlist.name}" will be permanently deleted. '
                'Songs in your library are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context.read<MusicProvider>().deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (playlists) ───────────────────────────────────

class _EmptyPlaylists extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlaylists({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.queue_music_rounded,
                size: 32, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('No playlists yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Create your first playlist to get started',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Playlist'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PlaylistDetailScreen
// ══════════════════════════════════════════════════════════════

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    // Sync the live playlist object from provider (in case it was updated).
    final live = music.playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );
    final allSongs = music.songs;
    final playlistSongs = live.songIds
        .map((id) {
          final idx = allSongs.indexWhere((s) => s.id == id);
          return idx >= 0 ? allSongs[idx] : null;
        })
        .whereType<Song>()
        .toList();

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(live.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded),
            tooltip: 'Add songs',
            onPressed: () => _showAddSongsSheet(context, live, allSongs),
          ),
          if (playlistSongs.isNotEmpty)
            IconButton(
              icon:
                  Icon(Icons.play_arrow_rounded, color: cs.primary, size: 28),
              tooltip: 'Play all',
              onPressed: () => music.playPlaylist(live),
            ),
        ],
      ),
      body: playlistSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No songs in this playlist',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddSongsSheet(context, live, allSongs),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add songs'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: playlistSongs.length,
              itemBuilder: (ctx, i) {
                final s = playlistSongs[i];
                final isCurrent = music.currentSong?.id == s.id;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCurrent && music.isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.music_note_rounded,
                      color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  title: Text(s.title,
                      style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCurrent ? cs.primary : null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      s.artist.isNotEmpty ? s.artist : 'Unknown Artist',
                      maxLines: 1),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.displayDuration,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20, color: Colors.red),
                        tooltip: 'Remove from playlist',
                        onPressed: () => music.removeSongFromPlaylist(
                            live.id, s.id),
                      ),
                    ],
                  ),
                  onTap: s.hasLocalFile
                      ? () =>
                          music.playSong(s, fromQueue: playlistSongs)
                      : null,
                );
              },
            ),
    );
  }

  void _showAddSongsSheet(
    BuildContext context,
    Playlist live,
    List<Song> allSongs,
  ) {
    final candidates =
        allSongs.where((s) => !live.songIds.contains(s.id)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All library songs are in this playlist')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Add songs to "${live.name}"',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final s = candidates[i];
                  return ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(s.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        s.artist.isNotEmpty ? s.artist : 'Unknown Artist'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      context
                          .read<MusicProvider>()
                          .addSongToPlaylist(live.id, s.id);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
