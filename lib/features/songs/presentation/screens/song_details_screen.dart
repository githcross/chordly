import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _songFuture =
        FirebaseFirestore.instance.collection('songs').doc(widget.songId).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Canción'),
        actions: [
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
      body: FutureBuilder<DocumentSnapshot>(
        future: _songFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Canción no encontrada'));
          }

          final songData = snapshot.data!.data() as Map<String, dynamic>;

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
                        Text(
                          songData['lyrics'] ?? 'Sin letra',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
