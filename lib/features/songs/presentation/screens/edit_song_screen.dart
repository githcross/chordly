import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';

class EditSongScreen extends ConsumerStatefulWidget {
  final SongModel song;

  const EditSongScreen({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends ConsumerState<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _lyricsController;
  late final TextEditingController _tempoController;
  late final TextEditingController _durationController;

  List<String> _availableNotes = [];
  List<String> _availableTags = [];
  late String _selectedKey;
  late List<String> _selectedTags;
  late String _status;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.song.title);
    _authorController = TextEditingController(text: widget.song.author);
    _lyricsController = TextEditingController(text: widget.song.lyrics);
    _tempoController =
        TextEditingController(text: widget.song.tempo.toString());
    _durationController = TextEditingController(text: widget.song.duration);
    _selectedKey = widget.song.baseKey;
    _selectedTags = List.from(widget.song.tags);
    _status = widget.song.status;
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
      final updatedSong = widget.song.copyWith(
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        lyrics: _lyricsController.text.trim(),
        baseKey: _selectedKey,
        tags: _selectedTags,
        tempo: int.tryParse(_tempoController.text) ?? 0,
        duration: _durationController.text.trim(),
        status: _status,
      );

      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.song.id)
          .update(updatedSong.toMap());

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción actualizada correctamente')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
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
        title: const Text('Editar Canción'),
        actions: [
          FilledButton.icon(
            onPressed: _updateSong,
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
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
                decoration: const InputDecoration(
                  labelText: 'Título *',
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
                decoration: const InputDecoration(
                  labelText: 'Autor *',
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
                decoration: const InputDecoration(
                  labelText: 'Tono *',
                  border: OutlineInputBorder(),
                ),
                items: _availableNotes
                    .map((note) => DropdownMenuItem(
                          value: note,
                          child: Text(note),
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
                      decoration: const InputDecoration(
                        labelText: 'BPM',
                        border: OutlineInputBorder(),
                        hintText: '120',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duración (mm:ss)',
                        border: OutlineInputBorder(),
                        hintText: '3:45',
                      ),
                      keyboardType: TextInputType.datetime,
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
              const Text('Tags'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags
                    .map((tag) => FilterChip(
                          label: Text(tag),
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
                controller: _lyricsController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La letra es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'borrador',
                    label: Text('Borrador'),
                  ),
                  ButtonSegment(
                    value: 'publicado',
                    label: Text('Publicado'),
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
