import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

class CreatePlaylistScreen extends StatefulWidget {
  final String groupId;
  final List<String> selectedSongs;

  const CreatePlaylistScreen({
    super.key,
    required this.groupId,
    required this.selectedSongs,
  });

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  List<PlaylistSongItem> _songs = [];
  bool _isLoading = true;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    _selectedDate = DateTime.now();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songsData = await Future.wait(
        widget.selectedSongs.map((id) =>
            FirebaseFirestore.instance.collection('songs').doc(id).get()),
      );

      _songs = songsData.asMap().entries.map((entry) {
        final doc = entry.value;
        final data = doc.data() as Map<String, dynamic>;
        final duration = _parseDuration(data['duration'] ?? '00:00');
        _totalDuration += duration;
        return PlaylistSongItem(
          songId: doc.id,
          order: entry.key,
          transposedKey: data['baseKey'],
          notes: '',
          duration: data['duration'] ?? '00:00',
        );
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      // Manejar error
      setState(() => _isLoading = false);
    }
  }

  Duration _parseDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length == 2) {
      return Duration(
          minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
    }
    return Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Crear Playlist', style: AppTextStyles.appBarTitle(context)),
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
            Text(
              'Canciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._buildSongsList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSongsList() {
    return _songs
        .map((song) => StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('songs')
                  .doc(song.songId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    child: ListTile(
                      title: Text('Cargando...'),
                    ),
                  );
                }

                final songData = snapshot.data!.data() as Map<String, dynamic>;
                final title = songData['title'] as String? ?? 'Sin título';
                final author =
                    songData['author'] as String? ?? 'Autor desconocido';

                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(author),
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
                );
              },
            ))
        .toList();
  }

  Future<void> _savePlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final playlistRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('playlists')
          .doc();

      final playlist = PlaylistModel(
        id: playlistRef.id,
        name: _nameController.text.trim(),
        groupId: widget.groupId,
        date: _selectedDate,
        createdBy: FirebaseAuth.instance.currentUser!.uid,
        createdAt: DateTime.now(),
        songs: _songs,
        notes: _notesController.text.trim(),
      );

      await playlistRef.set({
        'id': playlist.id,
        'name': playlist.name,
        'groupId': playlist.groupId,
        'date': playlist.date,
        'createdBy': playlist.createdBy,
        'createdAt': playlist.createdAt,
        'notes': playlist.notes,
        'status': PlaylistStatus.draft.name,
        'songs': _songs
            .map((song) => {
                  'songId': song.songId,
                  'duration': song.duration,
                  'order': song.order,
                  'transposedKey': song.transposedKey,
                  'notes': song.notes,
                })
            .toList(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist creada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear playlist: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          duration: song.duration,
        );
      });
    }
  }
}
