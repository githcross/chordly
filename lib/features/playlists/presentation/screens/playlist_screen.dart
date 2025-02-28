import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/presentation/screens/select_songs_screen.dart';
import 'package:chordly/features/playlists/presentation/screens/create_playlist_screen.dart';
import 'package:chordly/features/playlists/presentation/screens/playlist_details_screen.dart';

class PlaylistScreen extends StatelessWidget {
  final String groupId;

  const PlaylistScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('playlists')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final playlists = snapshot.data!.docs;
              if (playlists.isEmpty) {
                return Center(
                  child: Text(
                    'No hay playlists',
                    style: AppTextStyles.subtitle(context),
                  ),
                );
              }

              return ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final data = playlist.data() as Map<String, dynamic>;
                  return Dismissible(
                    key: Key(playlist.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar playlist'),
                          content: const Text(
                              '¿Estás seguro de que quieres eliminar esta playlist?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      FirebaseFirestore.instance
                          .collection('groups')
                          .doc(groupId)
                          .collection('playlists')
                          .doc(playlist.id)
                          .delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Playlist eliminada'),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text(
                        data['name'] ?? 'Sin nombre',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle:
                          Text('${(data['songs'] as List).length} canciones'),
                      leading: const Icon(Icons.queue_music),
                      onTap: () {
                        _openPlaylist(context, playlist.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _createPlaylist(BuildContext context) async {
    final selectedSongs = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSongsScreen(
          groupId: groupId,
        ),
      ),
    );

    print('Canciones seleccionadas: $selectedSongs');

    if (selectedSongs != null && selectedSongs.isNotEmpty) {
      print('Navegando a CreatePlaylistScreen');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePlaylistScreen(
            groupId: groupId,
            selectedSongs: selectedSongs,
          ),
        ),
      );
    } else {
      print('No se seleccionaron canciones');
    }
  }

  void _openPlaylist(BuildContext context, String playlistId) {
    print('ID de la playlist seleccionada: $playlistId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsScreen(
          playlistId: playlistId,
          groupId: groupId,
        ),
      ),
    );
  }
}
