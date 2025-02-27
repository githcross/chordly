import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/playlists/models/playlist_model.dart';
import 'package:chordly/features/playlists/presentation/screens/edit_playlist_screen.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/rendering.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;
  final String groupId;

  const PlaylistDetailsScreen({
    Key? key,
    required this.playlistId,
    required this.groupId,
  }) : super(key: key);

  @override
  _PlaylistDetailsScreenState createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('playlists')
          .doc(widget.playlistId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorScreen('Playlist no encontrada');
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final songs = (data['songs'] as List?) ?? [];
        final date = (data['date'] as Timestamp).toDate();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Fondo con efecto de profundidad
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade700,
                              Colors.indigo.shade600,
                            ],
                          ),
                        ),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(color: Colors.black.withOpacity(0.1)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              data['name'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildBannerItem(
                                  '${(data['songs'] as List).length} canciones',
                                ),
                                const SizedBox(width: 16),
                                _buildBannerItem(
                                  _formatDurationCompact(
                                      _calculateTotalDuration(
                                          data['songs'] as List)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_month,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy - HH:mm', 'es')
                                      .format(date),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['notes']?.isNotEmpty ?? false)
                        _buildNotesSection(data['notes']),
                      const SizedBox(height: 24),
                      Text(
                        'Canciones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              _buildSongList(songs),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue.shade700,
            child: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => _editPlaylist(context, data),
          ),
        );
      },
    );
  }

  Widget _buildNotesSection(String notes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              width: 4,
              color: Colors.blue.shade300.withOpacity(0.3),
            ),
          ),
        ),
        child: Text(
          notes,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.85),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(List<dynamic> songs) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          final songId = song is Map ? song['songId'] : song;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('songs')
                .doc(songId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final songData = snapshot.data!.data() as Map<String, dynamic>;
              final transposedKey = song is Map ? song['transposedKey'] : '';

              return ListTile(
                onTap: () =>
                    _navigateToSongDetails(context, songId, index, songs),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_outlined,
                    color: Colors.blue.shade600.withOpacity(0.8),
                    size: 20,
                  ),
                ),
                title: Text(
                  songData['title'] ?? 'Sin título',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  songData['author'] ?? 'Autor desconocido',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                trailing: songData['duration']?.isNotEmpty ?? false
                    ? Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          songData['duration']!,
                          style: TextStyle(
                            color: Colors.blue.shade600.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : Text(
                        '--:--',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            },
          );
        },
        childCount: songs.length,
      ),
    );
  }

  void _navigateToSongDetails(
    BuildContext context,
    String songId,
    int index,
    List<dynamic> songs,
  ) {
    final songIds = songs.map((item) {
      if (item is Map) return item['songId'] as String;
      return item as String;
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailsScreen(
          songId: songId,
          groupId: widget.groupId,
          playlistSongs: songIds,
          currentIndex: index,
          fromPlaylist: true,
        ),
      ),
    );
  }

  void _editPlaylist(BuildContext context, Map<String, dynamic> data) {
    print('ID de la playlist seleccionada: ${widget.playlistId}'); // Depuración
    print('ID del grupo: ${widget.groupId}'); // Depuración
    final List<dynamic> rawSongs = (data['songs'] as List?) ?? [];

    final songs = rawSongs.map((item) {
      final String songId;
      if (item is Map) {
        songId = item['songId'] as String;
      } else {
        songId = item as String;
      }

      return PlaylistSongItem(
        songId: songId,
        order: rawSongs.indexOf(item),
        transposedKey:
            item is Map ? item['transposedKey'] as String? ?? '' : '',
        notes: item is Map ? item['notes'] as String? ?? '' : '',
        duration:
            item is Map ? (item['duration'] as String?) ?? '00:00' : '00:00',
      );
    }).toList();

    final playlist = PlaylistModel(
      id: widget.playlistId,
      name: data['name'],
      groupId: widget.groupId,
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      songs: songs,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlaylistScreen(playlist: playlist),
      ),
    );
  }

  Widget _buildErrorScreen(String errorMessage) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(errorMessage)),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data, Duration totalDuration) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildStatItem(
        Icons.schedule,
        _formatDurationCompact(totalDuration),
        'Duración total',
        iconColor: Colors.white.withOpacity(0.85),
        textColor: Colors.white.withOpacity(0.9),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label,
      {Color? iconColor, Color? textColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatDurationCompact(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return [
      if (hours > 0) '${hours}h',
      '${minutes}m',
      if (seconds > 0) '${seconds}s'
    ].join(' ');
  }

  Duration _calculateTotalDuration(List<dynamic> songs) {
    Duration totalDuration = Duration.zero;

    for (var song in songs) {
      if (song is Map && song['duration'] != null) {
        final durationString = song['duration'].toString();
        final parts = durationString.split(':');

        // Manejar formato mm:ss
        if (parts.length == 2) {
          totalDuration += Duration(
            minutes: int.tryParse(parts[0]) ?? 0,
            seconds: int.tryParse(parts[1]) ?? 0,
          );
        }
        // Manejar formato hh:mm:ss
        else if (parts.length == 3) {
          totalDuration += Duration(
            hours: int.tryParse(parts[0]) ?? 0,
            minutes: int.tryParse(parts[1]) ?? 0,
            seconds: int.tryParse(parts[2]) ?? 0,
          );
        }
      }
    }
    return totalDuration;
  }

  Widget _buildBannerItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
