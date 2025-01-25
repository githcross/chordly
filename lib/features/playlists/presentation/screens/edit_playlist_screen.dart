import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';
import 'package:chordly/features/playlists/presentation/screens/select_songs_screen.dart';

class EditPlaylistScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const EditPlaylistScreen({
    Key? key,
    required this.playlist,
  }) : super(key: key);

  @override
  State<EditPlaylistScreen> createState() => _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends State<EditPlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late List<PlaylistSongItem> _songs;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _notesController = TextEditingController(text: widget.playlist.notes);
    _selectedDate = widget.playlist.date;
    _songs = List.from(widget.playlist.songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Editar Playlist', style: AppTextStyles.appBarTitle(context)),
        actions: [
          TextButton.icon(
            onPressed: _savePlaylist,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Playlist',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Canciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addSongs,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildSongsList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSongsList() {
    return _songs.map((song) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('songs')
            .doc(song.songId)
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

          return Dismissible(
            key: Key(song.songId),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) {
              setState(() {
                _songs.remove(song);
              });
            },
            child: Card(
              child: ListTile(
                title: Text(songData['title']),
                subtitle: Text(songData['author']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(song.transposedKey),
                    IconButton(
                      icon: const Icon(Icons.music_note),
                      onPressed: () => _showTransposeDialog(song),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Future<void> _addSongs() async {
    final selectedSongs = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSongsScreen(
          groupId: widget.playlist.groupId,
        ),
      ),
    );

    if (selectedSongs != null && selectedSongs.isNotEmpty) {
      _addSelectedSongs(selectedSongs);
    }
  }

  void _addSelectedSongs(List<String> selectedSongIds) {
    // Convertir la lista actual de canciones a un Set de IDs para búsqueda eficiente
    final existingSongIds = Set<String>.from(
      widget.playlist.songs.map((song) => song.songId),
    );

    // Filtrar las canciones seleccionadas para excluir las que ya están en la playlist
    final newSongIds = selectedSongIds.where(
      (id) => !existingSongIds.contains(id),
    );

    if (newSongIds.isEmpty) {
      // Mostrar mensaje si todas las canciones ya están en la playlist
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las canciones seleccionadas ya están en la playlist'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Agregar solo las canciones nuevas
    setState(() {
      widget.playlist.songs.addAll(
        newSongIds.map(
          (id) => PlaylistSongItem(
            songId: id,
            order: widget.playlist.songs.length,
            transposedKey: '',
            notes: '',
          ),
        ),
      );
    });

    // Mostrar mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se ${newSongIds.length == 1 ? 'agregó' : 'agregaron'} ${newSongIds.length} ${newSongIds.length == 1 ? 'canción' : 'canciones'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showTransposeDialog(PlaylistSongItem song) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Tonalidad'),
        content: DropdownButton<String>(
          value: song.transposedKey,
          items:
              ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
                  .map((key) => DropdownMenuItem(
                        value: key,
                        child: Text(key),
                      ))
                  .toList(),
          onChanged: (value) {
            if (value != null) {
              Navigator.pop(context, value);
            }
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        final index = _songs.indexOf(song);
        _songs[index] = PlaylistSongItem(
          songId: song.songId,
          order: song.order,
          transposedKey: result,
          notes: song.notes,
        );
      });
    }
  }

  Future<void> _savePlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('playlists')
          .doc(widget.playlist.id)
          .update({
        'name': _nameController.text.trim(),
        'notes': _notesController.text.trim(),
        'date': _selectedDate,
        'songs': _songs
            .map((song) => {
                  'songId': song.songId,
                  'order': song.order,
                  'transposedKey': song.transposedKey,
                  'notes': song.notes,
                })
            .toList(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist actualizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar playlist: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
