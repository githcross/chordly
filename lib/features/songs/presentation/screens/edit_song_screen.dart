import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/core/theme/text_styles.dart';

class EditSongScreen extends ConsumerStatefulWidget {
  final String songId;
  final String groupId;

  const EditSongScreen({
    Key? key,
    required this.songId,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends ConsumerState<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _lyricsController;
  late TextEditingController _tempoController;
  late TextEditingController _durationController;

  List<String> _availableNotes = [];
  List<String> _availableTags = [];
  late String _selectedKey;
  late List<String> _selectedTags;
  late String _status;
  bool _isLoading = true;
  String? _error;
  late Future<DocumentSnapshot> _songFuture;
  late Map<String, dynamic> _songData;

  @override
  void initState() {
    super.initState();
    _songFuture = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get()
        .then((snapshot) {
      _songData = snapshot.data() as Map<String, dynamic>;

      setState(() {
        _titleController = TextEditingController(text: _songData['title']);
        _authorController = TextEditingController(text: _songData['author']);
        _lyricsController = TextEditingController(text: _songData['lyrics']);
        _tempoController =
            TextEditingController(text: ((_songData['tempo'] ?? 0).toString()));
        _durationController =
            TextEditingController(text: _songData['duration'] ?? '');

        _selectedKey = _songData['baseKey'] ?? '';
        _selectedTags = List.from(_songData['tags'] ?? []);
        _status = _songData['status'] ?? 'borrador';
        _isLoading = false;
      });

      return snapshot;
    }).catchError((error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    });

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final notesDoc = await FirebaseFirestore.instance
          .collection('chords')
          .doc('notes')
          .get();
      final tagsDoc = await FirebaseFirestore.instance
          .collection('tags')
          .doc('default')
          .get();

      setState(() {
        _availableNotes = List<String>.from(notesDoc.data()?['notes'] ?? []);
        _availableTags = List<String>.from(tagsDoc.data()?['tags'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSong() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authProvider).value;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      // Verificar si el usuario actual no es el creador original
      final isOriginalCreator = _songData['createdBy'] == currentUser.uid;

      // Preparar datos de actualización
      final updatedSongData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'lyrics': _lyricsController.text.trim(),
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'tempo': int.tryParse(_tempoController.text) ?? 0,
        'duration': _durationController.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': {
          'userId': currentUser.uid,
          'userName': currentUser.displayName ?? currentUser.email,
        },
      };

      // Agregar colaboradores si no es el creador original
      if (!isOriginalCreator) {
        updatedSongData['collaborators'] = FieldValue.arrayUnion([
          {
            'userId': currentUser.uid,
            'userName': currentUser.displayName ?? currentUser.email,
          }
        ]);
      }

      // Actualizar la canción en Firestore
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update(updatedSongData);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Canción actualizada correctamente',
            style: AppTextStyles.buttonText(context),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al actualizar: $e',
            style: AppTextStyles.buttonText(context),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _validateDuration(String? value) {
    if (value == null || value.isEmpty) return null;

    final pattern = RegExp(r'^\d{1,2}:\d{2}$');
    if (!pattern.hasMatch(value)) {
      return 'Formato inválido. Use mm:ss';
    }

    final parts = value.split(':');
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);

    if (seconds >= 60) {
      return 'Los segundos deben ser menores a 60';
    }

    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _lyricsController.dispose();
    _tempoController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text('Error: $_error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Editar Canción', style: AppTextStyles.appBarTitle(context)),
        actions: [
          FilledButton.icon(
            onPressed: _updateSong,
            icon: const Icon(Icons.save),
            label: Text('Guardar', style: AppTextStyles.buttonText(context)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: AppTextStyles.inputText(context),
                decoration: InputDecoration(
                  labelText: 'Título *',
                  labelStyle: AppTextStyles.metadata(context),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                style: AppTextStyles.inputText(context),
                decoration: InputDecoration(
                  labelText: 'Autor *',
                  labelStyle: AppTextStyles.metadata(context),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El autor es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedKey,
                style: AppTextStyles.inputText(context),
                decoration: InputDecoration(
                  labelText: 'Tono *',
                  labelStyle: AppTextStyles.metadata(context),
                  border: OutlineInputBorder(),
                ),
                items: _availableNotes
                    .map((note) => DropdownMenuItem(
                          value: note,
                          child: Text(note,
                              style: AppTextStyles.itemTitle(context)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedKey = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El tono es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tempoController,
                      style: AppTextStyles.inputText(context),
                      decoration: InputDecoration(
                        labelText: 'BPM',
                        labelStyle: AppTextStyles.metadata(context),
                        border: OutlineInputBorder(),
                        hintText: '120',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      style: AppTextStyles.inputText(context),
                      decoration: InputDecoration(
                        labelText: 'Duración (mm:ss)',
                        labelStyle: AppTextStyles.metadata(context),
                        border: OutlineInputBorder(),
                        hintText: '3:45',
                      ),
                      validator: _validateDuration,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        LengthLimitingTextInputFormatter(5),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text;
                          if (text.isEmpty) return newValue;
                          if (text.contains(':')) {
                            if (text.length > 5) return oldValue;
                            return newValue;
                          }
                          if (text.length == 2) {
                            return TextEditingValue(
                              text: '$text:',
                              selection: TextSelection.collapsed(
                                  offset: text.length + 1),
                            );
                          }
                          if (text.length > 2 && !text.contains(':')) {
                            return oldValue;
                          }
                          return newValue;
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Tags', style: AppTextStyles.sectionTitle(context)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags
                    .map((tag) => FilterChip(
                          label:
                              Text(tag, style: AppTextStyles.metadata(context)),
                          selected: _selectedTags.contains(tag),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              LyricsInputField(
                songId: widget.songId,
                controller: _lyricsController,
                style: AppTextStyles.lyrics(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa la letra de la canción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'borrador',
                    label: Text('Borrador',
                        style: AppTextStyles.buttonText(context)),
                  ),
                  ButtonSegment(
                    value: 'publicado',
                    label: Text('Publicado',
                        style: AppTextStyles.buttonText(context)),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _status = newSelection.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
