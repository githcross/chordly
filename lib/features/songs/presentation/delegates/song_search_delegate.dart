import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/songs/models/song_model.dart';

class SongSearchDelegate extends SearchDelegate<SongModel?> {
  final String groupId;

  SongSearchDelegate({required this.groupId});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
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
    if (query.isEmpty) {
      return const Center(
        child: Text('Ingresa un título o autor para buscar'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: groupId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final songs = snapshot.data!.docs
            .map((doc) =>
                SongModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .where((song) {
          final searchLower = query.toLowerCase();
          return song.title.toLowerCase().contains(searchLower) ||
              song.author.toLowerCase().contains(searchLower);
        }).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                const Text('No se encontraron canciones'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 8,
                children: song.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ))
                    .toList(),
              ),
              onTap: () {
                // TODO: Navegar a la vista detallada de la canción
                close(context, song);
              },
            );
          },
        );
      },
    );
  }
}
