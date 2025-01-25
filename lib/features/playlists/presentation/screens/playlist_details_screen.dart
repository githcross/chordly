import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';
import 'package:chordly/features/playlists/presentation/screens/edit_playlist_screen.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({
    Key? key,
    required this.playlistId,
  }) : super(key: key);

  @override
  _PlaylistDetailsScreenState createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Inicializar datos de localización
    initializeDateFormatting('es');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('playlists')
          .doc(widget.playlistId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> songs = (data['songs'] as List?) ?? [];

        return Scaffold(
          appBar: AppBar(
            title:
                Text(data['name'], style: AppTextStyles.appBarTitle(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Información',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Información'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Fecha de creación'),
                            subtitle: Text(
                              DateFormat('EEEE, d MMMM yyyy', 'es')
                                  .format(data['createdAt'].toDate()),
                            ),
                          ),
                          if (data['updatedAt'] != null)
                            ListTile(
                              leading: const Icon(Icons.update),
                              title: const Text('Última actualización'),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy HH:mm')
                                    .format(data['updatedAt'].toDate()),
                              ),
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPlaylist(context, data),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data['notes']?.isNotEmpty ?? false)
                _buildInfoSection(context, data),
              const SizedBox(height: 24),
              Text(
                'Canciones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _buildSongList(songs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notes,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                  Text(
                    data['notes'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList(List<dynamic> songs) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getSongsStream(songs),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final songDocs = snapshot.data!;
        _calculateTotalDuration(songDocs);

        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songDocs.length + 1,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex >= songs.length || newIndex > songs.length) return;

            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = songs.removeAt(oldIndex);
              songs.insert(newIndex, item);

              FirebaseFirestore.instance
                  .collection('playlists')
                  .doc(widget.playlistId)
                  .update({'songs': songs});
            });
          },
          itemBuilder: (context, index) {
            if (index == songDocs.length) {
              return ListTile(
                key: const Key('summary'),
                leading: const Icon(Icons.timer),
                title: Text(
                  'Tiempo total: ${_formatDuration(_totalDuration)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }

            final songDoc = songDocs[index];
            final songData = songDoc.data() as Map<String, dynamic>;
            final duration = _parseDuration(songData['duration']);

            return ListTile(
              key: Key(songDoc.id),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_handle),
                  const SizedBox(width: 8),
                  Text('${index + 1}'),
                ],
              ),
              title: Text(songData['title']),
              subtitle: Text(songData['author'] ?? ''),
              trailing: Text(_formatDuration(duration)),
              onTap: () => _navigateToSongDetails(
                context,
                songDoc.id,
                index,
                songs,
              ),
            );
          },
        );
      },
    );
  }

  Duration _parseDuration(String? durationStr) {
    if (durationStr == null) return Duration.zero;
    final parts = durationStr.split(':');
    if (parts.length != 2) return Duration.zero;

    try {
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      return Duration(minutes: minutes, seconds: seconds);
    } catch (e) {
      return Duration.zero;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _calculateTotalDuration(List<DocumentSnapshot> songs) {
    _totalDuration = songs.fold(
      Duration.zero,
      (total, song) => total + _parseDuration((song.data() as Map)['duration']),
    );
  }

  Stream<List<DocumentSnapshot>> _getSongsStream(List<dynamic> songs) {
    if (songs.isEmpty) return Stream.value([]);

    // Extraer los IDs de las canciones del mapa
    final List<String> ids = songs.map((item) {
      if (item is Map) {
        return item['songId'] as String;
      }
      return item as String;
    }).toList();

    // Dividir en chunks de 10 para evitar límites de Firestore
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(
        ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10),
      );
    }

    // Combinar streams para cada chunk
    return Rx.combineLatest(
      chunks.map(
        (chunk) => FirebaseFirestore.instance
            .collection('songs')
            .where(FieldPath.documentId, whereIn: chunk)
            .snapshots()
            .map((snapshot) => snapshot.docs),
      ),
      (List<List<DocumentSnapshot<Object?>>> results) {
        final allDocs = results.expand((docs) => docs).toList();
        // Ordenar según el orden original de songIds
        allDocs.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
        return allDocs;
      },
    );
  }

  void _navigateToSongDetails(
    BuildContext context,
    String songId,
    int index,
    List<dynamic> songs,
  ) {
    // Extraer los IDs de las canciones
    final songIds = songs.map((item) {
      if (item is Map) {
        return item['songId'] as String;
      }
      return item as String;
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailsScreen(
          songId: songId,
          groupId: '',
          playlistSongs: songIds,
          currentIndex: index,
        ),
      ),
    );
  }

  void _editPlaylist(BuildContext context, Map<String, dynamic> data) {
    final List<dynamic> rawSongs = (data['songs'] as List?) ?? [];

    final songs = rawSongs.map((item) {
      final String songId;
      if (item is Map) {
        songId = item['songId'] as String;
      } else {
        songId = item as String;
      }

      return PlaylistSongItem(
        songId: songId,
        order: rawSongs.indexOf(item),
        transposedKey:
            item is Map ? item['transposedKey'] as String? ?? '' : '',
        notes: item is Map ? item['notes'] as String? ?? '' : '',
      );
    }).toList();

    final playlist = PlaylistModel(
      id: widget.playlistId,
      name: data['name'],
      groupId: data['groupId'],
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      songs: songs,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlaylistScreen(playlist: playlist),
      ),
    );
  }
}
