import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha y Hora de Uso'),
              subtitle: Text(
                DateFormat('EEEE, d MMMM yyyy - HH:mm', 'es')
                    .format(_selectedDate),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (selectedDate != null) {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  if (selectedTime != null) {
                    setState(() {
                      _selectedDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                    });
                  }
                }
              },
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
          final displayKey = song.transposedKey.isNotEmpty
              ? song.transposedKey
              : songData['baseKey'] ?? '';

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
                    if (displayKey.isNotEmpty) Text(displayKey),
                    IconButton(
                      icon: const Icon(Icons.music_note),
                      onPressed: () =>
                          _showTransposeDialog(song, songData['baseKey'] ?? ''),
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
      final newSongs = selectedSongs
          .where((id) => !_songs.any((song) => song.songId == id))
          .toList();
      final newSongItems = await Future.wait(
        newSongs.map((id) async {
          final doc = await FirebaseFirestore.instance
              .collection('songs')
              .doc(id)
              .get();
          final data = doc.data() as Map<String, dynamic>;
          return PlaylistSongItem(
            songId: id,
            order: _songs.length + newSongs.indexOf(id),
            transposedKey: data['baseKey'] ?? '',
            notes: '',
            duration: data['duration']?.toString() ?? '00:00',
          );
        }),
      );

      setState(() {
        _songs.addAll(newSongItems);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se agregaron ${newSongs.length} canciones'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showTransposeDialog(
      PlaylistSongItem song, String baseKey) async {
    final currentKey =
        song.transposedKey.isNotEmpty ? song.transposedKey : baseKey;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Tonalidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tono original: $baseKey'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: currentKey,
              hint: const Text('Seleccionar tono'),
              items: [
                'C',
                'C#',
                'D',
                'D#',
                'E',
                'F',
                'F#',
                'G',
                'G#',
                'A',
                'A#',
                'B'
              ]
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, baseKey);
            },
            child: const Text('Restaurar Original'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        final index = _songs.indexOf(song);
        _songs[index] = PlaylistSongItem(
          songId: song.songId,
          order: song.order,
          transposedKey: result == baseKey ? '' : result,
          notes: song.notes,
          duration: song.duration,
        );
      });
    }
  }

  Future<void> _savePlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final playlistRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.playlist.groupId)
          .collection('playlists')
          .doc(widget.playlist.id);

      final playlistDoc = await playlistRef.get();
      if (!playlistDoc.exists) {
        throw Exception('La playlist no existe');
      }

      await playlistRef.update({
        'name': _nameController.text.trim(),
        'notes': _notesController.text.trim(),
        'date': _selectedDate,
        'songs': _songs
            .map((song) => {
                  'songId': song.songId,
                  'order': song.order,
                  'transposedKey': song.transposedKey,
                  'notes': song.notes,
                  'duration': song.duration,
                })
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist actualizada con éxito'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar playlist: $e'),
            behavior: SnackBarBehavior.floating,
          ),
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
