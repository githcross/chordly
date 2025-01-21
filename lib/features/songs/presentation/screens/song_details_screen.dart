import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:chordly/features/songs/services/chord_service.dart';

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
  late Future<DocumentSnapshot> _songFuture;
  late String _originalLyrics;
  late String _lyrics;
  final ChordService _chordService = ChordService();

  @override
  void initState() {
    super.initState();
    _loadSongData();
  }

  void _loadSongData() {
    setState(() {
      _songFuture = FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .get()
          .then((snapshot) {
        final songData = snapshot.data() as Map<String, dynamic>;
        _originalLyrics = songData['lyrics'] ?? '';
        _lyrics = _originalLyrics;
        return snapshot;
      });
    });
  }

  // Método para resaltar y transponer acordes
  Widget _buildHighlightedLyrics(BuildContext context) {
    final chordRegex = RegExp(r'\(([^)]+)\)');

    final parts = _lyrics.split(chordRegex);
    final chords =
        chordRegex.allMatches(_lyrics).map((m) => m.group(1)!).toList();

    List<TextSpan> textSpans = [];

    for (int i = 0; i < parts.length; i++) {
      // Texto de la letra
      textSpans.add(TextSpan(
        text: parts[i],
        style: Theme.of(context).textTheme.bodyLarge,
      ));

      // Acordes resaltados
      if (i < chords.length) {
        textSpans.add(TextSpan(
          text: '(${chords[i]})',
          style: TextStyle(
            color: Colors.lightBlueAccent,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: textSpans),
      textAlign: TextAlign.left,
    );
  }

  // Método para transponer acordes y guardar en Firestore
  void _transposeChords(bool isHalfStepUp) async {
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

    setState(() {
      _lyrics = transposedLyrics;
    });

    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({'lyrics': transposedLyrics});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la transposición: $e')),
      );
    }
  }

  // Método para restaurar acordes originales
  void _restoreOriginalChords() async {
    setState(() {
      _lyrics = _originalLyrics;
    });

    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({'lyrics': _originalLyrics});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al restaurar acordes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Canción'),
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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSongScreen(
                    songId: widget.songId,
                    groupId: widget.groupId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.songId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Canción no encontrada'));
          }

          final songData = snapshot.data!.data() as Map<String, dynamic>;
          _lyrics = songData['lyrics'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Nombre de la Canción
                Text(
                  songData['title'] ?? 'Sin título',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Detalles Principales
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Base Key
                        _buildInfoRow(context, Icons.music_note, 'Clave Base',
                            songData['baseKey'] ?? 'No especificada'),
                        const SizedBox(height: 8),

                        // 3. Letra
                        Text(
                          'Letra',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        _buildHighlightedLyrics(context),
                        const SizedBox(height: 8),

                        // 4. Autor
                        _buildInfoRow(context, Icons.person, 'Autor',
                            songData['author'] ?? 'Desconocido'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Metadatos
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 5. Creado por
                        _buildInfoRow(
                            context,
                            Icons.person_outline,
                            'Creado por',
                            songData['creatorName'] ?? 'Desconocido'),
                        const SizedBox(height: 8),

                        // 6. Fecha de Creación
                        _buildInfoRow(
                            context,
                            Icons.calendar_today,
                            'Fecha de Creación',
                            _formatTimestamp(songData['createdAt'])),
                        const SizedBox(height: 8),

                        // 7. Fecha de Última Actualización
                        _buildInfoRow(
                            context,
                            Icons.update,
                            'Última Actualización',
                            _formatTimestamp(songData['updatedAt'])),
                        const SizedBox(height: 8),

                        // 8. Tags
                        _buildTagsRow(context, songData['tags'] ?? []),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
}
