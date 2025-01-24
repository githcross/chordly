import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/songs/models/song_model.dart';

class SelectSongsScreen extends StatefulWidget {
  final String groupId;

  const SelectSongsScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<SelectSongsScreen> createState() => _SelectSongsScreenState();
}

class _SelectSongsScreenState extends State<SelectSongsScreen> {
  final List<String> _selectedSongs = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seleccionar Canciones',
          style: AppTextStyles.appBarTitle(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectedSongs.isNotEmpty
                ? () => Navigator.pop(context, _selectedSongs)
                : null,
            icon: const Icon(Icons.check),
            label: Text('Listo (${_selectedSongs.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar canciones...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('songs')
                  .where('groupId', isEqualTo: widget.groupId)
                  .where('isActive', isEqualTo: true)
                  .where('status', isEqualTo: 'publicado')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data!.docs
                    .map((doc) => SongModel.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ))
                    .where((song) =>
                        _searchQuery.isEmpty ||
                        song.title.toLowerCase().contains(_searchQuery) ||
                        song.author.toLowerCase().contains(_searchQuery))
                    .toList();

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isSelected = _selectedSongs.contains(song.id);

                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.music_note,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(song.title),
                      subtitle: Text(song.author),
                      trailing: Text(song.baseKey),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedSongs.remove(song.id);
                          } else {
                            _selectedSongs.add(song.id);
                          }
                        });
                      },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
