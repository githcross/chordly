import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/utils/snackbar_utils.dart';
import 'package:chordly/features/songs/models/lyric_document.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';

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
  bool _isLyricsFullScreen = false;

  @override
  void initState() {
    super.initState();
    _songFuture = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get()
        .then((snapshot) {
      _songData = snapshot.data() as Map<String, dynamic>;

      // Asegurarnos de usar siempre la letra original, nunca la transpuesta
      final originalLyrics = _songData['lyrics'] as String?;
      if (originalLyrics == null) {
        throw Exception('No se encontró la letra original de la canción');
      }

      setState(() {
        _titleController = TextEditingController(text: _songData['title']);
        _authorController = TextEditingController(text: _songData['author']);
        _lyricsController = TextEditingController(
            text: originalLyrics); // Usar específicamente lyrics
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
      final isOriginalCreator = _songData['creatorUserId'] == currentUser.uid;

      final newLyrics = _lyricsController.text;
      // Convertir a formato top usando LyricDocument
      final lyricDoc = LyricDocument.fromInlineText(newLyrics);
      final topFormat = lyricDoc.toTopFormat();

      // Obtener el estado actual de la canción
      final currentSong = await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .get();
      final currentData = currentSong.data() as Map<String, dynamic>;
      final currentLyrics = currentData['lyrics'] as String?;
      final currentTransposed = currentData['lyricsTranspose'] as String?;

      // Determinar si hay una transposición activa
      final hasActiveTransposition =
          currentTransposed != null && currentTransposed != currentLyrics;

      // Preparar datos de actualización
      final updatedSongData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'lyrics': newLyrics,
        // Si hay una transposición activa, actualizar lyricsTranspose proporcionalmente
        'lyricsTranspose': hasActiveTransposition
            ? _updateTransposedLyrics(
                currentLyrics ?? '', currentTransposed ?? '', newLyrics)
            : newLyrics,
        'topFormat': topFormat,
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'tempo': int.tryParse(_tempoController.text) ?? 0,
        'duration': _durationController.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': currentUser.uid,
      };

      // Agregar colaboradores si no es el creador original
      if (!isOriginalCreator) {
        updatedSongData['collaborators'] =
            FieldValue.arrayUnion([currentUser.uid]);
      }

      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update(updatedSongData);

      if (!mounted) return;
      Navigator.pop(
          context, true); // Retornar true para indicar que hubo cambios

      SnackBarUtils.showSnackBar(
        context,
        message: 'Canción actualizada correctamente',
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error al actualizar: $e',
        isError: true,
      );
    }
  }

  // Método para actualizar la letra transpuesta manteniendo la transposición relativa
  String _updateTransposedLyrics(
      String oldLyrics, String oldTransposed, String newLyrics) {
    try {
      // Si las letras son iguales, no hay cambios que hacer
      if (oldLyrics == newLyrics) return oldTransposed;

      // Obtener los acordes y su transposición actual
      final oldChordRegex = RegExp(r'\(([^)]+)\)');
      final oldMatches = oldChordRegex.allMatches(oldLyrics);
      final transposedMatches = oldChordRegex.allMatches(oldTransposed);

      // Crear un mapa de transposiciones
      final transpositionMap = <String, String>{};
      for (var i = 0; i < oldMatches.length; i++) {
        final oldChord = oldMatches.elementAt(i).group(1)!;
        final transposedChord = transposedMatches.elementAt(i).group(1)!;
        transpositionMap[oldChord] = transposedChord;
      }

      // Aplicar la misma transposición a los acordes en la nueva letra
      String result = newLyrics;
      final newMatches = oldChordRegex.allMatches(newLyrics);
      for (var match in newMatches) {
        final chord = match.group(1)!;
        final transposed = transpositionMap[chord] ?? chord;
        result = result.replaceFirst('($chord)', '($transposed)');
      }

      return result;
    } catch (e) {
      print('Error al actualizar transposición: $e');
      return newLyrics; // En caso de error, retornar la letra sin transponer
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

  Widget _buildStatusSelector() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final songData = snapshot.data!.data() as Map<String, dynamic>;
        final currentStatus = songData['status'] as String;
        final isPublished = currentStatus == 'publicado';

        return SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(
              value: 'borrador',
              label: const Text('Borrador'),
              enabled: !isPublished,
            ),
            const ButtonSegment<String>(
              value: 'publicado',
              label: Text('Publicado'),
            ),
          ],
          selected: {_status},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _status = newSelection.first;
            });
          },
        );
      },
    );
  }

  Widget _buildLyricsEditor() {
    if (_isLyricsFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Letra'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _isLyricsFullScreen = false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(5.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: LyricsInputField(
              songId: widget.songId,
              controller: _lyricsController,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14.0,
                  ),
              isFullScreen: true,
              onToggleFullScreen: () =>
                  setState(() => _isLyricsFullScreen = false),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa la letra de la canción';
                }
                return null;
              },
            ),
          ),
        ),
      );
    }

    return LyricsInputField(
      songId: widget.songId,
      controller: _lyricsController,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14.0,
          ),
      isFullScreen: false,
      onToggleFullScreen: () => setState(() => _isLyricsFullScreen = true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor, ingresa la letra de la canción';
        }
        return null;
      },
    );
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

    if (_isLyricsFullScreen) {
      return _buildLyricsEditor();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar Canción',
          style: AppTextStyles.appBarTitle(context),
        ),
        actions: [
          IconButton(
            onPressed: _updateSong,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(5),
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
              const SizedBox(height: 20),
              _buildLyricsEditor(),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Estado',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('songs')
                            .doc(widget.songId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final songData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final currentStatus = songData['status'] as String;
                          final isPublished = currentStatus == 'publicado';

                          return SegmentedButton<String>(
                            segments: [
                              ButtonSegment<String>(
                                value: 'borrador',
                                label: const Text('Borrador'),
                                enabled: !isPublished,
                              ),
                              const ButtonSegment<String>(
                                value: 'publicado',
                                label: Text('Publicado'),
                              ),
                            ],
                            selected: {_status},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _status = newSelection.first;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
