import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/features/songs/utils/string_similarity.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/utils/snackbar_utils.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';

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
  final _videoUrlController = TextEditingController();
  final _videoNotesController = TextEditingController();

  List<String> _availableNotes = [];
  List<String> _availableTags = [];
  String? _selectedKey;
  List<String> _selectedTags = [];
  String _status = 'borrador';
  bool _isLoading = true;
  String? _error;
  bool _isLyricsFullScreen = false;

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

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authProvider).value;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      final newSong = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'lyrics': _lyricsController.text.trim(),
        'lyricsTranspose': _lyricsController.text.trim(),
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'tempo': int.tryParse(_tempoController.text) ?? 0,
        'duration': _durationController.text.trim(),
        'status': _status,
        'createdBy': currentUser.uid,
        'creatorUserId': currentUser.uid,
        'lastUpdatedBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'groupId': widget.groupId,
        'isActive': true,
        'collaborators': [currentUser.uid],
      };

      // Agregar video de referencia si hay URL
      final videoUrl = _videoUrlController.text.trim();
      if (videoUrl.isNotEmpty) {
        newSong['videoReference'] = {
          'url': videoUrl,
          'notes': _videoNotesController.text.trim(),
        };
      }

      await FirebaseFirestore.instance.collection('songs').add(newSong);

      if (!mounted) return;
      Navigator.pop(context);
      SnackBarUtils.showSnackBar(
        context,
        message: 'Canción guardada correctamente',
      );
    } catch (e) {
      setState(() => _error = e.toString());
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error al guardar: $_error',
        isError: true,
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
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error al agregar tag: $e',
        isError: true,
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
    if (similarTitles.isNotEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        message: 'Ya existe una canción con un título similar',
        isError: true,
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

  String? _validateTempo(String? value) {
    if (value == null || value.isEmpty) return 'El BPM es obligatorio';

    final tempo = int.tryParse(value);
    if (tempo == null) return 'Debe ser un número válido';
    if (tempo < 20 || tempo > 300) return 'El BPM debe estar entre 20 y 300';

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
    _videoUrlController.dispose();
    _videoNotesController.dispose();
    super.dispose();
  }

  Widget _buildLyricsEditor() {
    if (_isLyricsFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Agregar Letra'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _isLyricsFullScreen = false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(5),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: LyricsInputField(
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

  void _openFullScreenEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFullScreenHeader(),
            Expanded(
              child: LyricsInputField(
                controller: _lyricsController,
                isFullScreen: true,
                onChordSelected: _insertChord,
              ),
            ),
            _buildEditorTools(),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildFullScreenHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Editor Completo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTools() {
    final basicSections = [
      {'name': 'Intro', 'emoji': '🎵', 'color': Colors.blue},
      {'name': 'Verse', 'emoji': '📝', 'color': Colors.green},
      {'name': 'Pre-Chorus', 'emoji': '🚀', 'color': Colors.purple},
      {'name': 'Chorus', 'emoji': '🎶', 'color': Colors.orange},
      {'name': 'Bridge', 'emoji': '🌉', 'color': Colors.purple},
      {'name': 'Outro', 'emoji': '🎸', 'color': Colors.brown},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...basicSections.map((section) => _buildToolButton(
                section['name'] as String,
                section['emoji'] as String,
                section['color'] as Color,
              )),
        ],
      ),
    );
  }

  Widget _buildToolButton(String section, String emoji, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: Text(emoji),
        label: Text(section),
        onPressed: () => _insertSectionTag(section),
      ),
    );
  }

  void _insertSectionTag(String section) {
    final text = '\n[$section]\n';
    final cursorPos = _lyricsController.selection.base.offset;
    _lyricsController.text = _lyricsController.text.replaceRange(
      cursorPos,
      cursorPos,
      text,
    );
    _lyricsController.selection = TextSelection.collapsed(
      offset: cursorPos + text.length,
    );
  }

  void _insertChord(String chord) {
    final cursorPos = _lyricsController.selection.base.offset;
    final newText = _lyricsController.text.replaceRange(
      cursorPos,
      cursorPos,
      '($chord)',
    );
    _lyricsController.text = newText;
    _lyricsController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPos + chord.length + 2),
    );
  }

  Widget _buildTagChips() {
    return Wrap(
      spacing: 8,
      children: _availableTags.map((tag) => _buildTagChip(tag)).toList(),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);
    return InputChip(
      label: Text(tag),
      selected: isSelected,
      onSelected: (selected) => setState(
          () => selected ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del tag',
            hintText: 'Ej: Rock, Balada, Navidad',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agregar Canción',
          style: AppTextStyles.appBarTitle(context),
        ),
        actions: [
          IconButton(
            onPressed: _saveSong,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección de Información Básica
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Información Básica',
                                  style: AppTextStyles.sectionTitle(context),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: constraints.maxWidth > 600
                                              ? 300
                                              : double.infinity,
                                          child: TextFormField(
                                            controller: _titleController,
                                            decoration: const InputDecoration(
                                              labelText: 'Título',
                                              prefixIcon: Icon(Icons.title),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'El título es obligatorio';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: constraints.maxWidth > 600
                                              ? 300
                                              : double.infinity,
                                          child: TextFormField(
                                            controller: _authorController,
                                            decoration: const InputDecoration(
                                              labelText: 'Artista/Grupo',
                                              prefixIcon: Icon(Icons.person),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'El artista es obligatorio';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de Configuración Musical
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '⚙️ Configuración Musical',
                                  style: AppTextStyles.sectionTitle(context),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        controller: _tempoController,
                                        decoration: const InputDecoration(
                                          labelText: 'BPM',
                                          prefixIcon: Icon(Icons.speed),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: _validateTempo,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedKey,
                                        decoration: const InputDecoration(
                                          labelText: 'Clave Base',
                                          prefixIcon: Icon(Icons.music_note),
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
                                            return 'Selecciona una clave';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de Letra
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '🎼 Letra y Acordes',
                                      style:
                                          AppTextStyles.sectionTitle(context),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.expand),
                                      onPressed: _openFullScreenEditor,
                                      tooltip: 'Editar en pantalla completa',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 250,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: _openFullScreenEditor,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        _lyricsController.text.isEmpty
                                            ? 'Toca para comenzar a editar la letra...'
                                            : _lyricsController.text,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de Tags
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('🏷️ Tags',
                                        style: AppTextStyles.sectionTitle(
                                            context)),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          size: 24),
                                      onPressed: _showAddTagDialog,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTagChips(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de Video
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🎥 Referencia de Video',
                                  style: AppTextStyles.sectionTitle(context),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _videoUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'URL del Video',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final videoId =
                                          YoutubePlayer.convertUrlToId(value);
                                      if (videoId == null) {
                                        return 'URL de YouTube inválida';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _videoNotesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notas sobre el video',
                                    hintText:
                                        'Agrega notas sobre la versión del video',
                                    prefixIcon: Icon(Icons.note),
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de Estado y Duración
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _durationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Duración (mm:ss)',
                                    prefixIcon: Icon(Icons.timer),
                                  ),
                                  keyboardType: TextInputType.datetime,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                    _TimeInputFormatter(),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SwitchListTile(
                                  title: Text(_status == 'publicado'
                                      ? 'Publicado'
                                      : 'Borrador'),
                                  subtitle: const Text('Estado de la canción'),
                                  value: _status == 'publicado',
                                  onChanged: (value) {
                                    setState(() => _status =
                                        value ? 'publicado' : 'borrador');
                                  },
                                  secondary: Icon(
                                    _status == 'publicado'
                                        ? Icons.public
                                        : Icons.drafts,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  void _addSong(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSongScreen(
          groupId: widget.groupId,
          isEditing: false,
        ),
      ),
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) return oldValue;

    String formatted = text;
    if (text.length > 2) {
      formatted = '${text.substring(0, 2)}:${text.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
