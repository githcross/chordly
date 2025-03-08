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
  Map<String, dynamic>? _playlistData;

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

        _playlistData = snapshot.data!.data() as Map<String, dynamic>;
        final songs = (_playlistData!['songs'] as List?) ?? [];
        final date = (_playlistData!['date'] as Timestamp).toDate();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final scrollPosition = constraints.biggest.height;
                    return FlexibleSpaceBar(
                      title: scrollPosition < 100
                          ? Text(
                              _playlistData!['name'],
                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(1 - scrollPosition / 100),
                                fontSize: 18,
                              ),
                            )
                          : null,
                      background: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/logo/background.jpg',
                              fit: BoxFit.cover,
                              color: Colors.black.withOpacity(0.4),
                              colorBlendMode: BlendMode.darken,
                            ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: const Color(0x80212A3E).withOpacity(
                                  0.3), // Azul oscuro semi-transparente
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _playlistData!['name'],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                    color: Colors.white.withOpacity(0.95),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildBannerItem(
                                      '${(songs).length} canciones',
                                    ),
                                    const SizedBox(width: 16),
                                    _buildBannerItem(
                                      _formatDurationCompact(
                                          _calculateTotalDuration(songs)),
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
                                      DateFormat(
                                              'EEEE, d MMMM yyyy - HH:mm', 'es')
                                          .format(date),
                                      style: TextStyle(
                                        color: Colors.white,
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
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_playlistData!['notes']?.isNotEmpty ?? false)
                        _buildNotesSection(_playlistData!['notes']),
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
            onPressed: () => _editPlaylist(context, _playlistData!),
            child: Icon(Icons.edit,
                color: Theme.of(context).colorScheme.onPrimary),
            heroTag: 'playlist_details_fab',
            mini: false,
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              width: 4,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
        child: Text(
          notes,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
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

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () =>
                      _navigateToSongDetails(context, songId, index, songs),
                  borderRadius: BorderRadius.circular(12),
                  hoverColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.03),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      songData['title'] ?? 'Sin título',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if ((int.tryParse(
                                              songData['tempo']?.toString() ??
                                                  '') ??
                                          0) >
                                      0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.speed,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${int.tryParse(songData['tempo']?.toString() ?? '') ?? 0}',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    songData['author'] ?? 'Autor desconocido',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildInlineIconText(
                                    Icons.music_note,
                                    transposedKey.isNotEmpty
                                        ? transposedKey
                                        : songData['baseKey'] ?? 'N/A',
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildInlineIconText(
                                    Icons.schedule,
                                    songData['duration'] ?? '--:--',
                                    Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
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
    final song = songs[index];
    final cachedData = song is Map ? song : null;
    final songIds = songs.map((item) {
      if (item is Map) return item['songId'] as String;
      return item as String;
    }).toList();

    final songIdToUse = song is Map ? song['songId'] as String : song as String;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailsScreen(
          songId: songIdToUse,
          groupId: widget.groupId,
          initialData: (cachedData as Map<String, dynamic>?) ?? {},
          playlistSongs: songIds.cast<String>(),
          playlistId: widget.playlistId,
          playlistName: _playlistData!['name'],
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

  Widget _buildMusicChip(BuildContext context, String? key, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            key ?? 'N/A',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(BuildContext context, String duration) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                duration,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (duration != '--:--')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatDurationToMinutes(duration),
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDurationToMinutes(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return '${minutes}m ${seconds}s';
      }
      return duration;
    } catch (_) {
      return duration;
    }
  }

  Widget _buildDetailChip(
      BuildContext context, String text, IconData icon, Color color,
      {String? secondaryText}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (secondaryText != null)
                Text(
                  secondaryText,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineIconText(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
