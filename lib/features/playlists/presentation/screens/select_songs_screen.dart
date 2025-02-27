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
  final Set<String> _selectedSongs = {};
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
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_selectedSongs.isNotEmpty) {
                Navigator.pop(context, _selectedSongs.toList());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Selecciona al menos una canción')),
                );
              }
            },
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

                if (songs.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay canciones disponibles',
                      style: AppTextStyles.subtitle(context),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isSelected = _selectedSongs.contains(song.id);

                    return CheckboxListTile(
                      title: Text(song.title),
                      subtitle: Text(song.author),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedSongs.add(song.id);
                          } else {
                            _selectedSongs.remove(song.id);
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
