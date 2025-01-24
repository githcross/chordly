import 'package:flutter/material.dart';
import 'package:chordly/core/theme/text_styles.dart';

class RehearsalPlaylistScreen extends StatelessWidget {
  final PlaylistModel playlist;

  const RehearsalPlaylistScreen({
    Key? key,
    required this.playlist,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ensayo: ${playlist.name}',
            style: AppTextStyles.appBarTitle(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Participantes',
            onPressed: () => _showParticipants(context),
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: 'Instrumentos',
            onPressed: () => _showInstruments(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRehearsalInfo(),
          Expanded(
            child: _buildSongsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startRehearsalMode(context),
        label: const Text('Iniciar Ensayo'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildRehearsalInfo() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Lugar: ${playlist.rehearsalInfo?.location ?? "No especificado"}'),
            const SizedBox(height: 8),
            Text('Duración estimada: ${playlist.estimatedDuration} minutos'),
            const SizedBox(height: 8),
            if (playlist.rehearsalInfo?.focusPoints.isNotEmpty ?? false) ...[
              const Text('Puntos a practicar:'),
              ...playlist.rehearsalInfo!.focusPoints.map(
                (point) => ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: Text(point),
                  dense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    return ListView.builder(
      itemCount: playlist.songs.length,
      itemBuilder: (context, index) {
        final song = playlist.songs[index];
        return RehearsalSongCard(
          song: song,
          onTap: () => _showSongDetails(context, song),
        );
      },
    );
  }
}
