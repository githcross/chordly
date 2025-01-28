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
                .collection('playlists')
                .where('groupId', isEqualTo: groupId)
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
                  return ListTile(
                    title: Text(data['name'] ?? 'Sin nombre'),
                    subtitle:
                        Text('${(data['songs'] as List).length} canciones'),
                    leading: const Icon(Icons.queue_music),
                    onTap: () {
                      _openPlaylist(context, playlist.id);
                    },
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

    if (selectedSongs != null && selectedSongs.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreatePlaylistScreen(
            groupId: groupId,
            selectedSongs: selectedSongs,
          ),
        ),
      );
    }
  }

  void _openPlaylist(BuildContext context, String playlistId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsScreen(
          playlistId: playlistId,
        ),
      ),
    );
  }
}
