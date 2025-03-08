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
                    movementDuration: const Duration(milliseconds: 300),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          data['name'] ?? 'Playlist sin nombre',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        subtitle: Text(
                          '${(data['songs'] as List).length} ${(data['songs'] as List).length == 1 ? 'canción' : 'canciones'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.queue_music,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          _openPlaylist(context, playlist.id);
                        },
                      ),
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
