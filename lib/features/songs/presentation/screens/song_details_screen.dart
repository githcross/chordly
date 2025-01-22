import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:chordly/features/songs/services/chord_service.dart';
import 'package:chordly/core/theme/text_styles.dart';

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
  late String _lyrics;
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
    final parts = _lyrics.split(chordRegex);
    final chords =
        chordRegex.allMatches(_lyrics).map((m) => m.group(1)!).toList();

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
    final chords =
        chordRegex.allMatches(_lyrics).map((m) => m.group(1)!).toList();

    final transposedChords = chords.map((chord) {
      return isHalfStepUp
          ? _chordService.transposeUp(chord)
          : _chordService.transposeDown(chord);
    }).toList();

    String transposedLyrics = _lyrics;
    for (int i = 0; i < chords.length; i++) {
      transposedLyrics = transposedLyrics.replaceAll(
        '(${chords[i]})',
        '(${transposedChords[i]})',
      );
    }

    // Actualizar estado local inmediatamente
    setState(() {
      _lyrics = transposedLyrics;
    });

    // Actualizar Firestore en segundo plano
    FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({'lyrics': transposedLyrics}).catchError((e) {
      if (!mounted) return;
      setState(() {
        _lyrics = _originalLyrics;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la transposición: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    });
  }

  void _restoreOriginalChords() {
    setState(() {
      _lyrics = _originalLyrics;
      _landscapeFontSize = 24.0;
    });

    // Actualizar Firestore en segundo plano
    FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({'lyrics': _originalLyrics}).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar acordes: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
                _lyrics = _originalLyrics;
              });
            },
          ),
        ],
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
        final newLyrics = songData['lyrics'] ?? '';

        // Inicializar la primera vez o actualizar cuando cambian los datos
        if (!_isInitialized || _originalLyrics != newLyrics) {
          _originalLyrics = newLyrics;
          _lyrics = newLyrics;
          _isInitialized = true;
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
                    if (!isLandscape)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _navigateToEdit(context),
                      ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildInfoPanel(context, songData),
                ),
              );
      },
    );
  }

  Widget _buildInfoPanel(BuildContext context, Map<String, dynamic> songData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          songData['title'] ?? 'Sin título',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.music_note,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24),
                      const SizedBox(width: 8),
                      Text(
                        songData['baseKey'] ?? 'No especificada',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (songData['tempo'] != null && songData['tempo'] != 0)
                  Row(
                    children: [
                      Icon(Icons.speed,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${songData['tempo']} BPM',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildHighlightedLyrics(context),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  context,
                  Icons.person,
                  'Autor',
                  songData['author'] ?? 'Desconocido',
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  context,
                  Icons.timer,
                  'Duración',
                  songData['duration'] ?? 'No especificada',
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  context,
                  Icons.person_outline,
                  'Creado por',
                  songData['creatorName'] ?? 'Desconocido',
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  context,
                  Icons.calendar_today,
                  'Fecha creación',
                  _formatTimestamp(songData['createdAt'] as Timestamp?),
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  context,
                  Icons.info_outline,
                  'Estado',
                  songData['status'] == 'publicado' ? 'Publicado' : 'Borrador',
                ),
                if (songData['collaborators'] != null &&
                    (songData['collaborators'] as List).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    context,
                    Icons.group,
                    'Colaboradores',
                    (songData['collaborators'] as List)
                        .map((c) => c.toString())
                        .join(', '),
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
        ),
      ],
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
}
