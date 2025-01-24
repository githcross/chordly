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
    return Scaffold(
      appBar: AppBar(
        title: Text('Playlists', style: AppTextStyles.appBarTitle(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlaylist(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('playlists')
            .where('groupId', isEqualTo: groupId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final playlists = snapshot.data!.docs;

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final data = playlist.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(data['date'].toDate()),
                  ),
                  trailing: Text('${data['songs'].length} canciones'),
                  onTap: () => _openPlaylist(context, playlist.id),
                ),
              );
            },
          );
        },
      ),
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
