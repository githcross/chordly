import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:intl/intl.dart';

class DeletedSongsScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const DeletedSongsScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<DeletedSongsScreen> createState() => _DeletedSongsScreenState();
}

class _DeletedSongsScreenState extends ConsumerState<DeletedSongsScreen> {
  String? _lastActionSongId;
  String? _lastActionSongTitle;
  OverlayEntry? _overlayEntry;

  Future<List<DocumentSnapshot>> _getPlaylistsContainingSong(
      String songId) async {
    final playlistsQuery = await FirebaseFirestore.instance
        .collection('playlists')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .get();

    return playlistsQuery.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final songs = List<String>.from(data['songs'] ?? []);
      return songs.contains(songId);
    }).toList();
  }

  Future<void> _removeSongFromPlaylists(
      String songId, List<DocumentSnapshot> playlists) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var playlist in playlists) {
      final data = playlist.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final songs = List<String>.from(data['songs'] ?? []);
      songs.remove(songId);
      batch.update(playlist.reference, {'songs': songs});
    }

    await batch.commit();
  }

  Future<bool> _handlePermanentDelete(SongModel song) async {
    final playlists = await _getPlaylistsContainingSong(song.id);

    if (playlists.isEmpty) {
      return await _showSimpleDeleteConfirmation(song);
    }

    if (!mounted) return false;

    final playlistNames = playlists.map((p) {
      final data = p.data() as Map<String, dynamic>?;
      return data?['name'] as String? ?? 'Playlist sin nombre';
    }).join(', ');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canción en uso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'La canción "${song.title}" está en las siguientes playlists:'),
            const SizedBox(height: 8),
            Text(
              playlistNames,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('¿Qué deseas hacer?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'cancel'}),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, {'action': 'remove_and_delete'}),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar de playlists y borrar'),
          ),
        ],
      ),
    );

    if (result == null || result['action'] == 'cancel') {
      return false;
    }

    if (result['action'] == 'remove_and_delete') {
      await _removeSongFromPlaylists(song.id, playlists);
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(song.id)
          .delete();
      return true;
    }

    return false;
  }

  Future<bool> _showSimpleDeleteConfirmation(SongModel song) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar permanentemente'),
            content: Text(
                '¿Estás seguro de eliminar permanentemente "${song.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Canciones Eliminadas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color:
                Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Las canciones se eliminarán permanentemente después de 7 días',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('songs')
                  .where('groupId', isEqualTo: widget.group.id)
                  .where('isActive', isEqualTo: false)
                  .orderBy('title')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data!.docs.map((doc) {
                  return SongModel.fromMap(
                      doc.id, doc.data() as Map<String, dynamic>);
                }).toList();

                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay canciones eliminadas'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return Dismissible(
                      key: Key(song.id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Eliminar permanentemente
                          final deleted = await _handlePermanentDelete(song);
                          if (deleted) {
                            _showActionBanner(song.title, true);
                          }
                          return deleted;
                        } else {
                          // Restaurar
                          await FirebaseFirestore.instance
                              .collection('songs')
                              .doc(song.id)
                              .update({'isActive': true});
                          _showActionBanner(song.title, false);
                          return true;
                        }
                      },
                      background: Container(
                        color: Theme.of(context).colorScheme.primary,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20.0),
                        child: const Icon(Icons.restore, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete_forever,
                            color: Colors.white),
                      ),
                      child: ListTile(
                        title: Text(
                          song.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        subtitle: Text(
                          song.author ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showActionBanner(String songTitle, bool isDelete) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isDelete ? Icons.delete_forever : Icons.restore,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDelete
                          ? 'Se eliminó permanentemente "$songTitle"'
                          : 'Se restauró "$songTitle"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
