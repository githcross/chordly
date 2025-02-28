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
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:chordly/features/songs/presentation/widgets/song_parser.dart';
import 'package:chordly/features/songs/providers/song_sections_provider.dart';
import 'package:chordly/features/songs/presentation/widgets/song_section.dart';

class EditSongScreen extends ConsumerStatefulWidget {
  final String? songId;
  final String groupId;
  final bool isEditing;

  const EditSongScreen({
    Key? key,
    this.songId,
    required this.groupId,
    required this.isEditing,
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
  late TextEditingController _videoUrlController;
  late TextEditingController _videoNotesController;

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
  bool _isInitialized = false;
  late String _originalLyrics;
  late String _transposedLyrics;

  @override
  void initState() {
    super.initState();
    _songFuture = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get()
        .then((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Documento de canción no encontrado');
      }

      _songData = snapshot.data() as Map<String, dynamic>;

      // Asegurarnos de usar siempre la letra original, nunca la transpuesta
      final originalLyrics = _songData['lyrics'] as String?;
      if (originalLyrics == null) {
        throw Exception('No se encontró la letra original de la canción');
      }

      final videoReference =
          _songData['videoReference'] as Map<String, dynamic>?;

      setState(() {
        _titleController = TextEditingController(text: _songData['title']);
        _authorController = TextEditingController(text: _songData['author']);
        _lyricsController = TextEditingController(text: originalLyrics);
        _tempoController = TextEditingController(
            text: (_songData['tempo'] ?? _songData['bpm'] ?? 0).toString());
        _durationController =
            TextEditingController(text: _songData['duration'] ?? '');
        _videoUrlController =
            TextEditingController(text: videoReference?['url'] ?? '');
        _videoNotesController =
            TextEditingController(text: videoReference?['notes'] ?? '');

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

    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _originalLyrics = _songData['lyrics'] ?? '';
            _transposedLyrics = _songData['lyricsTranspose'] ?? _originalLyrics;
            _isInitialized = true;
          });
        }
      });
    }
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrige los errores antes de guardar')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authProvider).value;
      if (currentUser == null) throw Exception('Usuario no autenticado');

      // Validar BPM
      final tempo = int.tryParse(_tempoController.text) ?? 0;
      if (tempo < 20 || tempo > 300) {
        throw Exception('El BPM debe estar entre 20 y 300');
      }

      final newLyrics = _lyricsController.text.trim();
      final originalLyrics = _songData['lyrics'] as String? ?? '';

      // Convertir a formato top usando LyricDocument
      final lyricDoc = LyricDocument.fromInlineText(newLyrics);
      final topFormat = lyricDoc.toTopFormat();

      // Preparar datos de actualización
      final updatedSongData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'lyrics': newLyrics,
        'lyricsTranspose': newLyrics,
        'topFormat': topFormat,
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'tempo': tempo,
        'duration': _durationController.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': currentUser.uid,
      };

      // Agregar video de referencia si hay URL
      final videoUrl = _videoUrlController.text.trim();
      if (videoUrl.isNotEmpty) {
        updatedSongData['videoReference'] = {
          'url': videoUrl,
          'notes': _videoNotesController.text.trim(),
        };
      } else {
        updatedSongData['videoReference'] = FieldValue.delete();
      }

      // Asegurar que la duración sea válida
      final duration = _durationController.text.trim();
      if (duration.isNotEmpty && _validateDuration(duration) == null) {
        updatedSongData['duration'] = duration;
      } else {
        updatedSongData['duration'] = FieldValue.delete();
      }

      // Obtener creador usando 'creatorUserId' o 'createdBy' como fallback
      final creatorUserId = _songData['creatorUserId'] as String? ??
          _songData['createdBy'] as String?;

      if (newLyrics != originalLyrics &&
          creatorUserId != null &&
          currentUser.uid != creatorUserId) {
        updatedSongData['collaborators'] =
            FieldValue.arrayUnion([currentUser.uid]);

        // Crear campo si no existe
        if (!_songData.containsKey('collaborators')) {
          updatedSongData['collaborators'] = [currentUser.uid];
        }
      }

      // Actualizar Firestore
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update(updatedSongData);

      if (mounted) {
        Navigator.pop(context, true);
        SnackBarUtils.showSnackBar(context, message: 'Canción guardada');
      }
    } on FormatException catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          message: 'Error en el formato del BPM: ${e.message}',
          isError: true,
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          message: 'Error de Firebase: ${e.message}',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          message: 'Error inesperado: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  String? _validateTempo(String? value) {
    if (value == null || value.isEmpty) return null;

    final tempo = int.tryParse(value);
    if (tempo == null) return 'Debe ser un número';
    if (tempo < 20 || tempo > 300) return 'El BPM debe estar entre 20 y 300';

    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _lyricsController.dispose();
    _tempoController.dispose();
    _durationController.dispose();
    _videoUrlController.dispose();
    _videoNotesController.dispose();
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

  Widget _buildLyricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLyricsHeader(),
        _buildLyricsInputField(),
      ],
    );
  }

  Widget _buildLyricsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Letra y Acordes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.expand),
            onPressed: () => _openFullScreenEditor(),
            tooltip: 'Editar en pantalla completa',
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsInputField() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
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
    ).then((_) {
      // Forzar la actualización del estado cuando se cierra el editor
      if (mounted) {
        setState(() {});
      }
    });
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

  Widget _buildFullScreenEditor() {
    return Card(
      elevation: 2,
      child: LyricsInputField(
        controller: _lyricsController,
        onChordSelected: _insertChord,
        isFullScreen: true,
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

    final advancedSections = [
      {'name': 'Refrain', 'emoji': '🔄', 'color': Colors.indigo},
      {'name': 'Vamp', 'emoji': '🔁', 'color': Colors.deepPurple},
      {'name': 'Interlude', 'emoji': '🎤', 'color': Colors.pink},
      {'name': 'Breakdown', 'emoji': '⬇️', 'color': Colors.teal},
      {'name': 'Build-Up', 'emoji': '🔺', 'color': Colors.red},
      {'name': 'Post-Chorus', 'emoji': '🎵', 'color': Colors.amber},
      {'name': 'Fade-Out', 'emoji': '🔚', 'color': Colors.grey},
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
          PopupMenuButton(
            icon: const Icon(Icons.expand_more),
            itemBuilder: (context) => advancedSections
                .map((section) => PopupMenuItem(
                      child: ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: section['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            section['emoji'] as String,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        title: Text(section['name'] as String),
                      ),
                      onTap: () => _insertSectionTag(section['name'] as String),
                    ))
                .toList(),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Canción' : 'Nueva Canción'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSong,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Metadatos Básicos
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sección de Referencia de Video
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _videoNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas sobre el video',
                        hintText: 'Agrega notas sobre la versión del video',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
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
                            style: AppTextStyles.sectionTitle(context)),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 24),
                          onPressed: _showAddTagDialog,
                          color: Theme.of(context).colorScheme.primary,
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

            // Editor de Letra
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
                          style: AppTextStyles.sectionTitle(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline),
                          onPressed: () => _showSectionGuide(context),
                          tooltip: 'Guía de secciones',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLyricsSection(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildDurationField(),
            _buildStatusSwitch(),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationField() {
    return TextFormField(
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
    );
  }

  Widget _buildStatusSwitch() {
    return SwitchListTile(
      title: Text(_status == 'publicado' ? 'Publicado' : 'Borrador'),
      subtitle: const Text('Estado de la canción'),
      value: _status == 'publicado',
      onChanged: (value) {
        setState(() => _status = value ? 'publicado' : 'borrador');
      },
      secondary: Icon(
        _status == 'publicado' ? Icons.public : Icons.drafts,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showSectionQuickMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('song_sections').get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sections = snapshot.data!.docs;

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
              ),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final data = sections[index].data() as Map<String, dynamic>;
                return _buildSectionButtonFromFirestore(data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionButtonFromFirestore(Map<String, dynamic> data) {
    return Tooltip(
      message: data['description'],
      child: ElevatedButton.icon(
        icon: Text(data['emoji']),
        label: Text(data['name']),
        onPressed: () => _addSection(data['name']),
        style: ElevatedButton.styleFrom(
          backgroundColor: _parseColor(data['defaultColor']),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  void _showSectionGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guía de Secciones Musicales'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<QuerySnapshot>(
            future:
                FirebaseFirestore.instance.collection('song_sections').get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();

              return SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Sección')),
                    DataColumn(label: Text('Descripción')),
                  ],
                  rows: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DataRow(cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(data['emoji']),
                            const SizedBox(width: 8),
                            Text(data['name']),
                          ],
                        ),
                      ),
                      DataCell(Text(data['description'])),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _addSection(String sectionName) {
    final cursorPos = _lyricsController.selection.base.offset;
    final newText = _lyricsController.text.replaceRange(
      cursorPos,
      cursorPos,
      '\n[$sectionName]\n',
    );
    _lyricsController.text = newText;
  }

  Widget _buildSectionPreview(List<SongSection> sections) {
    return Column(
      children: sections
          .map<Widget>((section) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: section.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(section.type),
                subtitle: Text(
                  section.content.length > 50
                      ? '${section.content.substring(0, 50)}...'
                      : section.content,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSectionButtons() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('song_sections')
          .orderBy('order')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final sections = snapshot.data!.docs;

        return Column(
          children: [
            _buildSectionGroup(
                sections.where((d) => !(d['isAdvanced'] ?? false))),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Bloques Avanzados'),
              children: [
                _buildSectionGroup(
                    sections.where((d) => d['isAdvanced'] ?? false)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionGroup(Iterable<QueryDocumentSnapshot> sections) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sections.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Tooltip(
          message: data['description'],
          child: ElevatedButton.icon(
            icon: Text(data['emoji']),
            label: Text(data['name']),
            onPressed: () => _addSection(data['name']),
            style: ElevatedButton.styleFrom(
              backgroundColor: _parseColor(data['defaultColor']),
              foregroundColor: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _parseColor(String hex) =>
      Color(int.parse(hex.replaceAll('#', '0xFF')));

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

  Widget _buildTagChips() {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('tags').doc('default').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final tags = List<String>.from(snapshot.data!['tags'] ?? []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: tags.map((tag) => _buildTagChip(tag)).toList(),
            ),
          ],
        );
      },
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

  Future<void> _addNewTag(String tag) async {
    final tagsRef =
        FirebaseFirestore.instance.collection('tags').doc('default');
    await tagsRef.update({
      'tags': FieldValue.arrayUnion([tag])
    });
    setState(() {});
  }

  Future<void> _saveSong() async {
    try {
      final lyricDoc = LyricDocument.fromInlineText(_lyricsController.text);
      final topFormat = lyricDoc.toTopFormat();
      final videoUrl = _videoUrlController.text.trim();
      final videoNotes = _videoNotesController.text.trim();

      final songRef =
          FirebaseFirestore.instance.collection('songs').doc(widget.songId);

      final updateData = {
        'title': _titleController.text,
        'author': _authorController.text,
        'lyrics': _lyricsController.text,
        'lyricsTranspose': _lyricsController.text,
        'topFormat': topFormat,
        'tempo': int.tryParse(_tempoController.text) ?? 0,
        'baseKey': _selectedKey,
        'tags': _selectedTags,
        'duration': _durationController.text.trim(),
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': ref.read(authProvider).value!.uid,
      };

      if (videoUrl.isNotEmpty) {
        updateData['videoReference'] = {'url': videoUrl, 'notes': videoNotes};
      } else {
        updateData['videoReference'] = FieldValue.delete();
      }

      final currentUser = ref.read(authProvider).value!;
      final creatorUserId = _songData['creatorUserId'] as String? ??
          _songData['createdBy'] as String?;

      if (creatorUserId != null && currentUser.uid != creatorUserId) {
        updateData['collaborators'] = FieldValue.arrayUnion([currentUser.uid]);
      }

      await songRef.update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción actualizada exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  void _showChordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Acorde'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildChordCategory('Mayores', Colors.blue),
              _buildChordCategory('Menores', Colors.green),
              _buildChordCategory('Séptima', Colors.orange),
              _buildChordCategory('Suspendidas', Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChordCategory(String title, Color color) {
    return ExpansionTile(
      title: Text(title),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          children: ['C', 'D', 'E', 'F', 'G', 'A', 'B']
              .map((note) => _buildChordButton(note, color))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildChordButton(String chord, Color color) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
        ),
        onPressed: () {
          _insertChord(chord);
          Navigator.pop(context);
        },
        child: Text(chord),
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
