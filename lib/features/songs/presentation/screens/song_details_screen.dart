import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:chordly/features/songs/services/chord_service.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/utils/snackbar_utils.dart';

class SongDetailsScreen extends ConsumerStatefulWidget {
  final String songId;
  final String groupId;

  const SongDetailsScreen({
    Key? key,
    required this.songId,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<SongDetailsScreen> createState() => _SongDetailsScreenState();
}

class _SongDetailsScreenState extends ConsumerState<SongDetailsScreen> {
  late Stream<DocumentSnapshot> _songStream;
  late String _originalLyrics;
  late String _transposedLyrics;
  final ChordService _chordService = ChordService();
  final TransformationController _transformationController =
      TransformationController();
  double _scale = 1.0;
  double _fontSize = 16.0;
  double _landscapeFontSize = 16.0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _songStream = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .snapshots();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Widget _buildHighlightedLyrics(
    BuildContext context, {
    bool isLandscape = false,
    double? fontSize,
  }) {
    final textColor = isLandscape
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color;
    final chordColor = isLandscape ? Colors.lightBlue : Colors.lightBlueAccent;

    final actualFontSize = fontSize ?? _fontSize;

    final chordRegex = RegExp(r'\(([^)]+)\)');
    final parts = _transposedLyrics.split(chordRegex);
    final chords = chordRegex
        .allMatches(_transposedLyrics)
        .map((m) => m.group(1)!)
        .toList();

    List<TextSpan> textSpans = [];

    for (int i = 0; i < parts.length; i++) {
      textSpans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontSize: actualFontSize,
          color: textColor,
          height: 1.5,
        ),
      ));

      if (i < chords.length) {
        textSpans.add(TextSpan(
          text: '(${chords[i]})',
          style: TextStyle(
            color: chordColor,
            fontWeight: FontWeight.bold,
            fontSize: actualFontSize,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: textSpans),
      textAlign: TextAlign.left,
    );
  }

  void _transposeChords(bool isHalfStepUp) {
    final chordRegex = RegExp(r'\(([^)]+)\)');
    final chords = chordRegex
        .allMatches(_transposedLyrics)
        .map((m) => m.group(1)!)
        .toList();

    final transposedChords = chords.map((chord) {
      return isHalfStepUp
          ? _chordService.transposeUp(chord)
          : _chordService.transposeDown(chord);
    }).toList();

    String newTransposedLyrics = _transposedLyrics;
    for (int i = 0; i < chords.length; i++) {
      newTransposedLyrics = newTransposedLyrics.replaceAll(
        '(${chords[i]})',
        '(${transposedChords[i]})',
      );
    }

    // Actualizar estado local inmediatamente
    setState(() {
      _transposedLyrics = newTransposedLyrics;
    });

    // Actualizar solo lyricsTranspose en Firestore
    FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({'lyricsTranspose': newTransposedLyrics}).catchError((e) {
      if (!mounted) return;
      setState(() {
        _transposedLyrics = _originalLyrics;
      });
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error al guardar la transposición: $e',
        isError: true,
      );
    });
  }

  void _restoreOriginalChords() {
    setState(() {
      _transposedLyrics = _originalLyrics;
      _landscapeFontSize = 24.0;
    });

    // Restaurar lyricsTranspose al valor original
    FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({'lyricsTranspose': _originalLyrics}).catchError((e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        message: 'Error al restaurar acordes: $e',
        isError: true,
      );
    });
  }

  Widget _buildLandscapeContent(
      BuildContext context, Map<String, dynamic> songData) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _fontSize = 16.0;
            });
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase, color: Colors.white),
            tooltip: 'Aumentar texto',
            onPressed: () {
              setState(() {
                _landscapeFontSize =
                    (_landscapeFontSize + 2.0).clamp(16.0, 40.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease, color: Colors.white),
            tooltip: 'Reducir texto',
            onPressed: () {
              setState(() {
                _landscapeFontSize =
                    (_landscapeFontSize - 2.0).clamp(16.0, 40.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            tooltip: 'Subir medio tono',
            onPressed: () => _transposeChords(true),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            tooltip: 'Bajar medio tono',
            onPressed: () => _transposeChords(false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Restaurar',
            onPressed: () {
              setState(() {
                _landscapeFontSize = 24.0;
                _transposedLyrics = _originalLyrics;
              });
            },
          ),
        ],
        title: Text(
          'Modo Presentación',
          style: AppTextStyles.appBarTitle(context),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_landscapeFontSize == 16.0) {
                    _landscapeFontSize = constraints.maxWidth * 0.03;
                  }
                  return _buildHighlightedLyrics(
                    context,
                    isLandscape: true,
                    fontSize: _landscapeFontSize,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return StreamBuilder<DocumentSnapshot>(
      stream: _songStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Canción no encontrada'));
        }

        final songData = snapshot.data!.data() as Map<String, dynamic>;
        final newOriginalLyrics = songData['lyrics'] ?? '';
        final newTransposedLyrics =
            songData['lyricsTranspose'] ?? newOriginalLyrics;

        // Actualizar el estado local cuando los datos cambian
        if (!_isInitialized || _originalLyrics != newOriginalLyrics) {
          // Si es la primera vez o si lyrics cambió (edición)
          _originalLyrics = newOriginalLyrics;
          _transposedLyrics =
              newOriginalLyrics; // Usar lyrics después de edición
          _isInitialized = true;
        } else if (_transposedLyrics != newTransposedLyrics) {
          // Si solo cambió lyricsTranspose (transposición)
          _transposedLyrics = newTransposedLyrics;
        }

        return isLandscape
            ? _buildLandscapeContent(context, songData)
            : Scaffold(
                appBar: AppBar(
                  title: Text(
                    'Detalles de la Canción',
                    style: AppTextStyles.appBarTitle(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Subir medio tono',
                      onPressed: () => _transposeChords(true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      tooltip: 'Bajar medio tono',
                      onPressed: () => _transposeChords(false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Restaurar acordes originales',
                      onPressed: _restoreOriginalChords,
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(1),
                  child: _buildInfoPanel(context, songData),
                ),
                floatingActionButton: PopupMenuButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () => Future.delayed(
                        const Duration(seconds: 0),
                        () => _navigateToEdit(context),
                      ),
                    ),
                    PopupMenuItem(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Información'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () => Future.delayed(
                        const Duration(seconds: 0),
                        () => _showInfoDialog(context, songData),
                      ),
                    ),
                  ],
                ),
              );
      },
    );
  }

  Widget _buildInfoPanel(BuildContext context, Map<String, dynamic> songData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contenedor para el encabezado
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                songData['title'] ?? 'Sin título',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    label: Text(
                      songData['baseKey'] ?? 'No especificada',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                  const SizedBox(width: 8),
                  if (songData['tempo'] != null && songData['tempo'] != 0)
                    Chip(
                      avatar: Icon(
                        Icons.speed,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                      label: Text(
                        '${songData['tempo']} BPM',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Separador visual
        const Divider(height: 1),
        // Contenedor para la letra
        Card(
          margin: EdgeInsets.zero, // Eliminar margen de la Card
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Eliminar bordes redondeados
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: _buildHighlightedLyrics(context),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context, Map<String, dynamic> songData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Información de la canción',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                context,
                Icons.person,
                'Autor',
                songData['author'] ?? 'Desconocido',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                Icons.timer,
                'Duración',
                songData['duration'] ?? 'No especificada',
              ),
              const SizedBox(height: 16),
              _buildCreatorInfo(songData['createdBy']),
              const SizedBox(height: 16),
              _buildDatesInfo(songData),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                Icons.info_outline,
                'Estado',
                songData['status'] == 'publicado' ? 'Publicado' : 'Borrador',
              ),
              if (songData['collaborators'] != null &&
                  (songData['collaborators'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCollaboratorsInfo(
                  List<String>.from(songData['collaborators'] as List),
                ),
              ],
              if (songData['tags'] != null &&
                  (songData['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildTagsRow(context, List<String>.from(songData['tags'])),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context, List<dynamic> tags) {
    return Row(
      children: [
        Icon(Icons.label, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Tags: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: tags
                .map((tag) => Chip(
                      label: Text(tag.toString()),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.5),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';
    final dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSongScreen(
          songId: widget.songId,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  Future<String> _getCreatorName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['displayName'] ?? 'Usuario desconocido';
      }
      return 'Usuario no encontrado';
    } catch (e) {
      return 'Error al cargar usuario';
    }
  }

  Widget _buildCreatorInfo(String creatorId) {
    return FutureBuilder<String>(
      future: _getCreatorName(creatorId),
      builder: (context, snapshot) {
        final creatorName = snapshot.data ?? 'Cargando...';
        return _buildInfoRow(
          context,
          Icons.person_outline,
          'Creado por',
          creatorName,
        );
      },
    );
  }

  Future<List<String>> _getCollaboratorNames(
      List<String> collaboratorIds) async {
    try {
      final collaboratorNames = await Future.wait(
        collaboratorIds.map((id) => _getCreatorName(id)),
      );
      return collaboratorNames;
    } catch (e) {
      return ['Error al cargar colaboradores'];
    }
  }

  Widget _buildCollaboratorsInfo(List<String> collaboratorIds) {
    return FutureBuilder<List<String>>(
      future: _getCollaboratorNames(collaboratorIds),
      builder: (context, snapshot) {
        final collaboratorNames = snapshot.data?.join(', ') ?? 'Cargando...';
        return _buildInfoRow(
          context,
          Icons.group,
          'Colaboradores',
          collaboratorNames,
        );
      },
    );
  }

  Future<String> _getLastUpdatedByName(String? userId) async {
    if (userId == null) return 'No disponible';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['displayName'] ?? 'Usuario no encontrado';
    } catch (e) {
      return 'Error al cargar usuario';
    }
  }

  Widget _buildDatesInfo(Map<String, dynamic> songData) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Fecha de creación'),
          subtitle:
              Text(_formatFirestoreDate(songData['createdAt'] as Timestamp?)),
        ),
        ListTile(
          leading: const Icon(Icons.update),
          title: const Text('Última actualización'),
          subtitle:
              Text(_formatFirestoreDate(songData['updatedAt'] as Timestamp?)),
        ),
        FutureBuilder<String>(
          future: _getLastUpdatedByName(songData['lastUpdatedBy'] as String?),
          builder: (context, snapshot) {
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Actualizado por'),
              subtitle: Text(snapshot.data ?? 'Cargando...'),
            );
          },
        ),
      ],
    );
  }

  String _formatFirestoreDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    final dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
}
