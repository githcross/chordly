import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/songs/utils/string_similarity.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';

class AddSongScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddSongScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _tempoController = TextEditingController();
  final _durationController = TextEditingController();

  List<String> _availableNotes = [];
  List<String> _availableTags = [];
  String? _selectedKey;
  List<String> _selectedTags = [];
  String _status = 'borrador';
  bool _isLoading = true;
  String? _error;

  final List<String> _defaultNotes = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'Bb',
    'B',
    'Cm',
    'C#m',
    'Dm',
    'Ebm',
    'Em',
    'Fm',
    'F#m',
    'Gm',
    'G#m',
    'Am',
    'Bbm',
    'Bm',
    'C7',
    'C#7',
    'D7',
    'Eb7',
    'E7',
    'F7',
    'F#7',
    'G7',
    'G#7',
    'A7',
    'Bb7',
    'B7',
    'Cm7',
    'C#m7',
    'Dm7',
    'Ebm7',
    'Em7',
    'Fm7',
    'F#m7',
    'Gm7',
    'G#m7',
    'Am7',
    'Bbm7',
    'Bm7'
  ];

  final _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) {
        _checkTitleSimilarity();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Cargar notas
      final chordsDoc = await FirebaseFirestore.instance
          .collection('chords')
          .doc('notes')
          .get();

      if (!chordsDoc.exists) {
        await FirebaseFirestore.instance
            .collection('chords')
            .doc('notes')
            .set({'notes': _defaultNotes});
        _availableNotes = [..._defaultNotes];
      } else {
        _availableNotes = List<String>.from(chordsDoc.data()?['notes'] ?? []);
      }

      // Cargar tags
      final tagsDoc = await FirebaseFirestore.instance
          .collection('tags')
          .doc('default')
          .get();

      if (!tagsDoc.exists) {
        // Crear documento con tags predefinidos
        await FirebaseFirestore.instance.collection('tags').doc('default').set({
          'tags': ['himnario', 'alabanzas especiales']
        });
        _availableTags = ['himnario', 'alabanzas especiales'];
      } else {
        _availableTags = List<String>.from(tagsDoc.data()?['tags'] ?? []);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Usuario no autenticado');

      // Buscar canciones similares
      final similarSongs = await FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: widget.groupId)
          .get();

      final String newTitle = _titleController.text.trim();
      final similarTitles = similarSongs.docs
          .where((doc) {
            final existingTitle = doc.data()['title'] as String;
            final similarity = StringSimilarity.calculateSimilarity(
              newTitle,
              existingTitle,
            );
            return similarity >= 90;
          })
          .map((doc) => doc.data()['title'] as String)
          .toList();

      if (similarTitles.isNotEmpty) {
        if (!mounted) return;

        // Mostrar diálogo de confirmación
        final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Canciones Similares Encontradas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se encontraron las siguientes canciones con nombres similares:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...similarTitles.map((title) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('• $title'),
                    )),
                const SizedBox(height: 16),
                const Text('¿Desea guardar de todas formas?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );

        if (shouldSave != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Continuar con el guardado
      final songData = {
        'title': newTitle,
        'author': _authorController.text,
        'lyrics': _lyricsController.text,
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'tempo': int.tryParse(_tempoController.text) ?? 0,
        'duration': _durationController.text.isEmpty
            ? '00:00'
            : _durationController.text,
        'status': _status,
        'createdBy': user.uid,
        'creatorName': user.displayName ?? user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'groupId': widget.groupId,
        'playlists': [],
        'isActive': true,
      };

      await FirebaseFirestore.instance.collection('songs').add(songData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción guardada exitosamente')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $_error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewTag(String newTag) async {
    try {
      await FirebaseFirestore.instance
          .collection('tags')
          .doc('default')
          .update({
        'tags': FieldValue.arrayUnion([newTag])
      });

      setState(() {
        _availableTags.add(newTag);
        _selectedTags.add(newTag);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _checkSimilarTitles(String title) async {
    if (title.trim().isEmpty) return [];

    final similarSongs = await FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.groupId)
        .get();

    return similarSongs.docs
        .where((doc) {
          final existingTitle = doc.data()['title'] as String;
          final similarity = StringSimilarity.calculateSimilarity(
            title,
            existingTitle,
          );
          return similarity >= 70; // Umbral de similitud
        })
        .map((doc) => doc.data()['title'] as String)
        .toList();
  }

  Future<void> _checkTitleSimilarity() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final similarTitles = await _checkSimilarTitles(title);
    if (similarTitles.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Títulos Similares Encontrados'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se encontraron las siguientes canciones con nombres similares:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...similarTitles.map((title) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('• $title'),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Puedes continuar escribiendo o modificar el título.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  String? _validateDuration(String? value) {
    if (value == null || value.isEmpty) return null; // Campo opcional

    // Validar formato mm:ss
    final RegExp durationRegex = RegExp(r'^([0-5]?[0-9]):([0-5][0-9])$');
    if (!durationRegex.hasMatch(value)) {
      return 'Formato inválido. Use mm:ss (ej: 3:45)';
    }
    return null;
  }

  @override
  void dispose() {
    _titleFocus.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Canción'),
        actions: [
          TextButton(
            onPressed: _saveSong,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    decoration: const InputDecoration(
                      labelText: 'Título *',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
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
                  DropdownButtonFormField<String>(
                    value: _selectedKey,
                    decoration: const InputDecoration(
                      labelText: 'Clave Base *',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableNotes.map((note) {
                      return DropdownMenuItem(
                        value: note,
                        child: Text(note),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedKey = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La clave base es obligatoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }),
                      ActionChip(
                        label: const Text('+ Nuevo Tag'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final controller = TextEditingController();
                              return AlertDialog(
                                title: const Text('Nuevo Tag'),
                                content: TextField(
                                  controller: controller,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre del tag',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      if (controller.text.isNotEmpty) {
                                        _addNewTag(controller.text);
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: const Text('Agregar'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tempoController,
                          decoration: const InputDecoration(
                            labelText: 'Tempo (BPM)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
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
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9:]')),
                            LengthLimitingTextInputFormatter(5),
                            // Formateador personalizado para ayudar con el formato
                            TextInputFormatter.withFunction(
                                (oldValue, newValue) {
                              final text = newValue.text;
                              if (text.isEmpty) return newValue;

                              // Si ya tiene los dos puntos, solo permitir números después
                              if (text.contains(':')) {
                                if (text.length > 5) return oldValue;
                                return newValue;
                              }

                              // Agregar los dos puntos automáticamente después de los minutos
                              if (text.length == 2) {
                                return TextEditingValue(
                                  text: '$text:',
                                  selection: TextSelection.collapsed(
                                      offset: text.length + 1),
                                );
                              }

                              // No permitir más de 2 dígitos antes de los dos puntos
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
    );
  }
}
