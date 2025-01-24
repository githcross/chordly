import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';
import 'package:chordly/features/playlists/presentation/screens/edit_playlist_screen.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';

class PlaylistDetailsScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailsScreen({
    Key? key,
    required this.playlistId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlistId)
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

        return Scaffold(
          appBar: AppBar(
            title:
                Text(data['name'], style: AppTextStyles.appBarTitle(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPlaylist(context, data),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInfoSection(context, data),
              const SizedBox(height: 24),
              Text(
                'Canciones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._buildSongsList(context, data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(BuildContext context, Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha: ${DateFormat('dd/MM/yyyy').format(data['date'].toDate())}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (data['notes']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Notas:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(data['notes']),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSongsList(
    BuildContext context,
    Map<String, dynamic> playlistData,
  ) {
    final songs = List<Map<String, dynamic>>.from(playlistData['songs']);

    return songs.map((song) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('songs')
            .doc(song['songId'])
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Card(
              child: ListTile(
                title: Text('Cargando...'),
              ),
            );
          }

          final songData = snapshot.data!.data() as Map<String, dynamic>;

          return Card(
            child: ListTile(
              title: Text(songData['title']),
              subtitle: Text(songData['author']),
              trailing: Text(song['transposedKey']),
              onTap: () => _openSongDetails(
                context,
                song['songId'],
                playlistData['groupId'],
                songs.map((s) => s['songId'] as String).toList(),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  void _openSongDetails(
    BuildContext context,
    String songId,
    String groupId,
    List<String> playlistSongs,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailsScreen(
          songId: songId,
          groupId: groupId,
          playlistSongs: playlistSongs,
          currentIndex: playlistSongs.indexOf(songId),
        ),
      ),
    );
  }

  void _editPlaylist(BuildContext context, Map<String, dynamic> data) {
    final playlist = PlaylistModel(
      id: playlistId,
      name: data['name'],
      groupId: data['groupId'],
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      songs: List<Map<String, dynamic>>.from(data['songs'])
          .map((song) => PlaylistSongItem(
                songId: song['songId'],
                order: song['order'],
                transposedKey: song['transposedKey'],
                notes: song['notes'] ?? '',
              ))
          .toList(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlaylistScreen(playlist: playlist),
      ),
    );
  }
}
