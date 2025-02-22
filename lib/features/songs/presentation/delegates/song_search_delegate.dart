import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/songs/models/song_model.dart';

class SongSearchDelegate extends SearchDelegate<String> {
  final String groupId;
  final Function(String) onSongSelected;

  SongSearchDelegate({
    required this.groupId,
    required this.onSongSelected,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: groupId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final songs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title'] as String? ?? '';
          final author = data['author'] as String? ?? '';
          final tempo = data['tempo']?.toString() ??
              '0'; // Asegurar que el tempo sea un String

          return title.toLowerCase().contains(query.toLowerCase()) ||
              author.toLowerCase().contains(query.toLowerCase()) ||
              tempo.contains(query);
        }).toList();

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final data = song.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'Sin título';
            final author = data['author'] as String? ?? 'Autor desconocido';
            final tempo = data['tempo']?.toString() ??
                '0'; // Asegurar que el tempo sea un String

            return ListTile(
              title: Text(title),
              subtitle: Text('$author - $tempo BPM'),
              onTap: () {
                close(context, song.id);
                onSongSelected(song.id);
              },
            );
          },
        );
      },
    );
  }
}
