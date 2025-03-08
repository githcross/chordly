import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/songs/presentation/screens/edit_song_screen.dart';
import 'package:chordly/features/songs/services/chord_service.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/core/utils/snackbar_utils.dart';
import 'package:chordly/features/songs/presentation/screens/teleprompter_screen.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:chordly/core/models/group_role.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui'; // Agregar este import para ImageFilter
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:chordly/features/songs/presentation/widgets/song_section.dart';
import 'package:chordly/features/songs/presentation/widgets/song_parser.dart';
import 'package:chordly/features/songs/providers/song_sections_provider.dart';
import 'package:chordly/features/songs/presentation/widgets/lyrics_input_field.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}

class SongDetailsScreen extends ConsumerStatefulWidget {
  final String songId;
  final String groupId;
  final Map<String, dynamic>? initialData;
  final List<String>? playlistSongs;
  final String? playlistId;
  final String? playlistName;

  const SongDetailsScreen({
    super.key,
    required this.songId,
    required this.groupId,
    this.initialData,
    this.playlistSongs,
    this.playlistId,
    this.playlistName,
  });

  @override
  ConsumerState<SongDetailsScreen> createState() => _SongDetailsScreenState();
}

class _SongDetailsScreenState extends ConsumerState<SongDetailsScreen> {
  late final Stream<DocumentSnapshot> _songStream;
  String? _resolvedGroupId;
  String _originalLyrics = '';
  String _transposedLyrics = '';
  final ChordService _chordService = ChordService();
  final TransformationController _transformationController =
      TransformationController();
  double _scale = 1.0;
  double _fontSize = 16.0;
  double _landscapeFontSize = 16.0;
  bool _isInitialized = false;
  final ScrollController _autoScrollController = ScrollController();
  bool _isAutoScrolling = false;
  double _scrollSpeed = 50.0; // Pixeles por segundo
  late final AudioPlayer _metronomePlayer;
  Timer? _metronomeTimer;
  int _firestoreBpm = 0;
  int? _localBpm;
  YoutubePlayerController? _videoController;
  bool _isVideoVisible = false;
  double _videoOffsetX = 0;
  double _videoOffsetY = 0;
  late Map<String, dynamic> _songData;
  bool _wasMetronomePlaying = false;
  bool _isMetronomeActive = false;
  int _currentSectionIndex = 0;
  late final ScrollController _sectionScrollController;
  List<String>? _playlistSongs;
  String? _playlistId;
  String? _playlistName;

  // Agregar getter para isLandscape
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // 1. Agregar variable _currentBpm como getter calculado
  int get effectiveBpm => _localBpm ?? _firestoreBpm;

  // 1. Restaurar getter de transposición
  bool get hasActiveTransposition => _transposedLyrics != _originalLyrics;

  // Agregar este getter
  String get lyricsToDisplay => _transposedLyrics;

  // 1. Definir estilos a nivel de clase
  static const _lyricsBaseStyle = TextStyle(
    fontFamily: 'Roboto',
    package: 'chordly', // Importante para fuentes en paquetes
    fontSize: 16,
    color: Color(0xFF333333),
    height: 1.8,
    letterSpacing: 0.3,
  );

  static final _chordStyle = _lyricsBaseStyle.copyWith(
    fontWeight: FontWeight.w900, // Black weight
    color: Color(0xFF2196F3),
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.15),
        offset: Offset(1, 1),
        blurRadius: 2,
      ),
    ],
  );

  // 2. Método optimizado para parsing
  List<TextSpan> _parseChords(String lyrics) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\([A-Ga-g][#b]?.*?\))');
    final parts = lyrics.split(regex);

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // Los índices impares son acordes
        spans.add(TextSpan(
          text: parts[i],
          style: _chordStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleChordTap(parts[i]),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: _lyricsBaseStyle,
        ));
      }
    }

    return spans;
  }

  // 3. Widget final con verificación de fuentes
  Widget _buildLyricsSection(String lyrics, String transposedLyrics) {
    return FutureBuilder<void>(
      future: _initializeLyrics(lyrics, transposedLyrics),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLyricsSkeleton();
        }
        return _buildLyricsContent();
      },
    );
  }

  Widget _buildLyricsSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 20,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent() {
    return RichText(
      text: TextSpan(
        style: _lyricsBaseStyle,
        children: _parseChords(lyricsToDisplay),
      ),
    );
  }

  // 4. Verificar disponibilidad de Roboto
  Future<bool> _isRobotoAvailable() async {
    try {
      final paragraphBuilder = ParagraphBuilder(
        ParagraphStyle(fontFamily: 'Roboto'),
      )..addText('Test');

      paragraphBuilder.build().layout(ParagraphConstraints(width: 100));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _sectionScrollController = ScrollController();

    // Inicializar las letras con los datos iniciales si están disponibles
    if (widget.initialData != null) {
      _originalLyrics = widget.initialData!['lyrics'] ?? '';
      _transposedLyrics =
          widget.initialData!['lyricsTranspose'] ?? _originalLyrics;
    }

    _initializeSongStream();
    _metronomePlayer = AudioPlayer();
    _initializeMetronome();
    _playlistSongs = widget.playlistSongs;
    _playlistId = widget.playlistId;
    _playlistName = widget.playlistName;
  }

  // 2. Método separado para inicializar el stream
  void _initializeSongStream() {
    _songStream = _getSongStream();
  }

  Stream<DocumentSnapshot> _getSongStream() {
    print('[FIRESTORE] Cargando canción ID: ${widget.songId}');
    print('[FIRESTORE] Grupo ID: ${widget.groupId}');

    return FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .snapshots()
        .handleError((error) {
      print('[FIRESTORE ERROR] $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando canción: $error')),
        );
      }
    });
  }

  @override
  void dispose() {
    _sectionScrollController.dispose();
    _transformationController.dispose();
    _autoScrollController.dispose();
    _metronomePlayer.dispose();
    _metronomeTimer?.cancel();
    _videoController?.dispose();
    _localBpm = null;
    super.dispose();
  }

  Widget _buildHighlightedLyrics(
    BuildContext context, {
    bool isLandscape = false,
    double? fontSize,
  }) {
    final actualFontSize = fontSize ?? _fontSize;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: DefaultTextStyle(
        key: ValueKey(_transposedLyrics),
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: actualFontSize,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.5,
        ),
        child: Builder(
          builder: (context) {
            final baseStyle = DefaultTextStyle.of(context).style;
            final chordStyle = baseStyle.merge(TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ));

            return RichText(
              text: _buildFormattedLyrics(
                lyricsToDisplay,
                baseStyle: baseStyle,
                chordStyle: chordStyle,
              ),
            );
          },
        ),
      ),
    );
  }

  TextSpan _buildFormattedLyrics(
    String lyrics, {
    required TextStyle baseStyle,
    required TextStyle chordStyle,
  }) {
    final List<TextSpan> textSpans = [];
    final RegExp noteRegex = RegExp(r'\((.*?)\)');

    int currentIndex = 0;
    for (final match in noteRegex.allMatches(lyrics)) {
      if (match.start > currentIndex) {
        textSpans.add(TextSpan(
          text: lyrics.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }

      final chordText = match.group(1)!;
      textSpans.add(TextSpan(
        text: '($chordText)',
        style: chordStyle,
      ));

      currentIndex = match.end;
    }

    if (currentIndex < lyrics.length) {
      textSpans.add(TextSpan(
        text: lyrics.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(
      style: baseStyle,
      children: textSpans,
    );
  }

  void _transposeChords(bool isHalfStepUp) {
    try {
      final chordRegex = RegExp(r'\(([^)]+)\)');
      final chords = chordRegex
          .allMatches(_transposedLyrics)
          .map((m) => m.group(1)!)
          .toList();

      final transposedChords = chords.map((chord) {
        try {
          return isHalfStepUp
              ? _chordService.transposeUp(chord)
              : _chordService.transposeDown(chord);
        } catch (e) {
          // Si no se puede transponer el acorde, mantener el original
          print('Error transponiendo acorde $chord: $e');
          return chord;
        }
      }).toList();

      String newTransposedLyrics = _transposedLyrics;
      for (int i = 0; i < chords.length; i++) {
        newTransposedLyrics = newTransposedLyrics.replaceAll(
          '(${chords[i]})',
          '(${transposedChords[i]})',
        );
      }

      // Usar un callback para actualizar el estado solo si es necesario
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _transposedLyrics != newTransposedLyrics) {
          setState(() {
            _transposedLyrics = newTransposedLyrics;
          });
        }
      });

      // Actualizar Firestore
      FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({'lyricsTranspose': newTransposedLyrics}).catchError((e) {
        if (mounted) {
          setState(() {
            _transposedLyrics = _originalLyrics;
          });
          SnackBarUtils.showSnackBar(
            context,
            message: 'Error al guardar la transposición: $e',
            isError: true,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          message: 'Error inesperado: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _restoreOriginalChords() {
    setState(() {
      _transposedLyrics = _originalLyrics;
    });

    // Actualizar Firestore
    FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({'lyricsTranspose': _originalLyrics}).catchError((e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          message: 'Error al restaurar acordes: $e',
          isError: true,
        );
      }
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _songStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Usar los datos iniciales mientras se carga
          if (widget.initialData != null) {
            return _buildSongContent(widget.initialData!);
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Canción no encontrada'));
        }

        final songData = snapshot.data!.data() as Map<String, dynamic>;
        _songData = songData;
        final newLyrics = songData['lyrics'] ?? '';
        final newTransposedLyrics = songData['lyricsTranspose'] ?? newLyrics;

        // Actualizar el estado local solo si es necesario
        if (!_isInitialized ||
            _originalLyrics != newLyrics ||
            _transposedLyrics != newTransposedLyrics) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _originalLyrics = newLyrics;
                _transposedLyrics = newTransposedLyrics;
                _firestoreBpm =
                    songData['tempo']?.toInt() ?? songData['bpm']?.toInt() ?? 0;
                _isInitialized = true;
                if (!_isMetronomeActive) {
                  _localBpm = null;
                }
              });
            }
          });
        }

        return StreamBuilder<GroupRole>(
          stream: _getUserRole(),
          builder: (context, roleSnapshot) {
            final userRole = roleSnapshot.data ?? GroupRole.member;
            final canEdit =
                userRole == GroupRole.admin || userRole == GroupRole.editor;

            return Scaffold(
              backgroundColor: isLandscape ? Colors.black : null,
              appBar:
                  isLandscape ? null : _buildAppBar(context, songData, canEdit),
              body: Stack(
                children: [
                  _buildSongContent(songData),
                  _buildMiniVideoPlayer(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Map<String, dynamic> songData,
    bool canEdit,
  ) {
    final key = songData['baseKey'] ?? 'N/A';
    final bpm = songData['tempo']?.toString() ?? 'N/A';
    final hasPlaylist =
        widget.playlistSongs != null && widget.playlistSongs!.isNotEmpty;

    return AppBar(
      title: GestureDetector(
        onTap: hasPlaylist ? () => _showPlaylistSongsSheet(context) : null,
        child: Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'song-${songData['id']}-title',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        songData['title'] ?? 'Detalles de canción',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ),
                    ),
                    if (hasPlaylist)
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            Text(
              '$bpm BPM',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        _buildSettingsMenu(context, songData, canEdit),
      ],
    );
  }

  Widget _buildMetadataChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  void _showSongsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canciones de la Playlist',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildSongsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    return const Center(child: Text('Funcionalidad de playlist no disponible'));
  }

  Widget _buildSongView(String songId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('songs')
          .doc(songId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final songData = snapshot.data!.data() as Map<String, dynamic>;
        _originalLyrics = songData['lyrics'];
        if (!_isInitialized) {
          _transposedLyrics = _originalLyrics;
          _isInitialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.present_to_all),
                tooltip: 'Modo Teleprompter',
                onPressed: () => _showTeleprompterMode(context, songData),
              ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                            ),
                            const SizedBox(width: 8),
                            if (songData['tempo'] != null &&
                                songData['tempo'] is int &&
                                songData['tempo'] > 0)
                              _buildBpmButton(
                                  context, songData['tempo'] as int),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: _buildHighlightedLyrics(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel(BuildContext context, Map<String, dynamic> songData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  if (songData['tempo'] != null &&
                      songData['tempo'] is int &&
                      songData['tempo'] > 0)
                    _buildBpmButton(context, songData['tempo'] as int),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: _buildHighlightedLyrics(context),
          ),
        ),
      ],
    );
  }

  void _showSongInfoDialog() {
    final songData = _songData;
    if (songData.isEmpty) return;

    final createdAt = _formatFirestoreDate(songData['createdAt'] as Timestamp?);
    final updatedAt = _formatFirestoreDate(songData['updatedAt'] as Timestamp?);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (songData['title'] != null)
                Text(
                  songData['title']!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              if (songData['author'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'por ${songData['author']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              const SizedBox(height: 24),
              _buildInfoSection(
                icon: Icons.music_note,
                title: 'Detalles Musicales',
                children: [
                  _buildInfoItem(
                      'Tonalidad', songData['baseKey'] ?? 'No especificada'),
                  _buildInfoItem('BPM', '${songData['tempo'] ?? 'N/A'}'),
                  _buildInfoItem('Versión', songData['version'] ?? '1.0'),
                ],
              ),
              const Divider(height: 40),
              _buildInfoSection(
                icon: Icons.history,
                title: 'Historial',
                children: [
                  _buildInfoItem('Creada el', createdAt),
                  _buildInfoItem('Última actualización', updatedAt),
                  FutureBuilder<String>(
                    future: _getLastUpdatedByName(
                        songData['lastUpdatedBy'] as String?),
                    builder: (context, snapshot) => _buildInfoItem(
                        'Actualizado por', snapshot.data ?? 'Cargando...'),
                  ),
                ],
              ),
              const Divider(height: 40),
              if (songData['collaborators'] != null &&
                  (songData['collaborators'] as List).isNotEmpty)
                _buildInfoSection(
                  icon: Icons.people_alt,
                  title: 'Colaboradores',
                  children: [
                    FutureBuilder<List<String>>(
                      future: _getCollaboratorNames(
                          (songData['collaborators'] as List<dynamic>)
                              .cast<String>()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        final collaboratorNames =
                            snapshot.data ?? ['No disponibles'];

                        return Wrap(
                          spacing: 8,
                          children: collaboratorNames
                              .map((name) => Chip(
                                    label: Text(name),
                                    avatar: Icon(
                                      Icons.person,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmButton(BuildContext context, int bpm) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: () => _showBpmDialog(context, bpm),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _metronomeTimer != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _metronomeTimer != null ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: _metronomeTimer != null
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$bpm BPM',
                style: TextStyle(
                  color: _metronomeTimer != null
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMetronome() {
    if (_metronomeTimer != null) {
      _stopMetronome();
    } else {
      _startMetronome();
    }
  }

  void _startMetronome() {
    final interval = (60000 / effectiveBpm).round();

    _metronomeTimer?.cancel();
    _metronomePlayer.stop();

    var nextBeat = DateTime.now().microsecondsSinceEpoch;
    const soundDuration = 50;
    const systemLatency = 20; // Latencia del sistema en ms

    _metronomeTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (timer) async {
        final now = DateTime.now().microsecondsSinceEpoch;
        if (now >= nextBeat) {
          final adjustedInterval =
              (interval - soundDuration - systemLatency) * 1000;
          nextBeat = now + adjustedInterval;

          await _metronomePlayer.seek(Duration.zero);
          await _metronomePlayer.play(AssetSource('audio/click.wav'));
        }
      },
    );

    setState(() => _isMetronomeActive = true);
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomePlayer.stop();
    setState(() => _isMetronomeActive = false);
  }

  void _adjustBpm(int delta) {
    final newBpm = (_localBpm ?? _firestoreBpm) + delta;
    _localBpm = newBpm.clamp(40, 240);

    setState(() {}); // 1. Actualización local del estado

    if (_isMetronomeActive) {
      _metronomeTimer?.cancel();
      _startMetronome(); // 2. Reinicio completo del metrónomo
    }

    // 3. Actualización visual forzada en el BottomSheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildBpmControls() {
    return StatefulBuilder(
      builder: (context, setLocalState) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 36,
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                _adjustBpm(-5);
                setLocalState(() {});
              },
            ),
            GestureDetector(
              onTap: () => _showBpmDialog(context, effectiveBpm),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$effectiveBpm BPM',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 36,
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                _adjustBpm(5);
                setLocalState(() {});
              },
            ),
          ],
        ),
      ),
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

  void _navigateToEditScreen() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSongScreen(
          songId: widget.songId,
          groupId: widget.groupId,
          isEditing: true,
        ),
      ),
    );
  }

  void _navigateToTeleprompter() {
    Navigator.pop(context); // Cerrar menú settings
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeleprompterScreen(
          lyrics: _transposedLyrics,
          title: _songData['title'],
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
        return _buildInfoRow('Creado por', creatorName);
      },
    );
  }

  Future<List<String>> _getCollaboratorNames(
      List<String> collaboratorIds) async {
    try {
      final collaborators = await Future.wait(
        collaboratorIds.map((id) async {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          return userDoc.data()?['displayName'] ?? 'Usuario desconocido';
        }),
      );
      return collaborators.cast<String>();
    } catch (e) {
      return ['Error al cargar colaboradores'];
    }
  }

  Widget _buildCollaboratorsInfo(List<String> collaboratorIds) {
    return FutureBuilder<List<String>>(
      future: _getCollaboratorNames(collaboratorIds),
      builder: (context, snapshot) {
        final collaboratorNames = snapshot.data?.join(', ') ?? 'Cargando...';
        return _buildInfoRow('Colaboradores', collaboratorNames);
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

  void _showTeleprompterMode(
      BuildContext context, Map<String, dynamic> songData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeleprompterScreen(
          title: songData['title'],
          lyrics: _transposedLyrics,
        ),
      ),
    );
  }

  Widget _buildSongContent(Map<String, dynamic> songData) {
    // Si no hay letras cargadas, usar las iniciales
    if (_originalLyrics.isEmpty && widget.initialData != null) {
      _originalLyrics = widget.initialData!['lyrics'] ?? '';
      _transposedLyrics =
          widget.initialData!['lyricsTranspose'] ?? _originalLyrics;
    }

    final sections = ref.watch(songSectionsProvider).asData?.value ?? [];
    final parsedSections = parseSongStructure(_transposedLyrics, sections);
    final sectionKeys =
        List.generate(parsedSections.length, (index) => GlobalKey());

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 60),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildSongStructure(parsedSections, songData, sectionKeys),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildFixedSectionIndex(parsedSections, sectionKeys),
        ),
      ],
    );
  }

  Widget _buildFixedSectionIndex(
      List<SongSection> sections, List<GlobalKey> keys) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListView.builder(
        controller: _sectionScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = index == _currentSectionIndex;

          return Builder(
            builder: (btnContext) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? (section.color?.withOpacity(0.3) ?? Colors.blue[100])
                        : (section.color?.withOpacity(0.1) ??
                            Colors.transparent),
                    foregroundColor: section.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? (section.color ?? Colors.blue)
                            : Colors.transparent,
                        width: isSelected ? 3 : 2,
                      ),
                    ),
                  ),
                  onPressed: () {
                    debugPrint(
                        'TAP en botón de sección: $index - ${section.type}');
                    setState(() => _currentSectionIndex = index);

                    Scrollable.ensureVisible(
                      keys[index].currentContext!,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );

                    _scrollToButton(index);
                  },
                  child: Text(
                    section.type.toUpperCase(),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _scrollToButton(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = 120.0;
    final scrollOffset =
        (buttonWidth * index) + (buttonWidth / 2) - (screenWidth / 2);

    if (_sectionScrollController.hasClients) {
      _sectionScrollController
          .animateTo(
        scrollOffset.clamp(
            0.0, _sectionScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        debugPrint('Scroll AUTOMÁTICO a botón: $index completado');
      });
    }
  }

  Widget _buildSongStructure(List<SongSection> sections,
      Map<String, dynamic> songData, List<GlobalKey> keys) {
    return Column(
      children: [
        const SizedBox(height: 24),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            final section = sections[index];
            final isSelected = index == _currentSectionIndex;

            return GestureDetector(
              onTap: () {
                debugPrint(
                    'TAP en tarjeta de sección: $index - ${section.type}');
                setState(() => _currentSectionIndex = index);

                Scrollable.ensureVisible(
                  keys[index].currentContext!,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ).then((_) {
                  debugPrint('Scroll AUTOMÁTICO a tarjeta: $index completado');
                });

                _scrollToButton(index);
              },
              child: Container(
                margin: const EdgeInsets.only(top: 24),
                child: Card(
                  key: keys[index],
                  elevation: isSelected ? 6 : 3,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? (section.color ??
                              Theme.of(context).colorScheme.primary)
                          : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -24,
                        left: 16,
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: section.color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: section.color?.withOpacity(0.3) ??
                                    Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              section.type.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 24, bottom: 10, left: 20, right: 20),
                        child: Text(
                          section.content,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsMenu(
      BuildContext context, Map<String, dynamic> songData, bool canEdit) {
    final videoReference = songData['videoReference'];
    final hasVideo = videoReference != null && videoReference['url'] != null;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      itemBuilder: (context) => [
        if (hasVideo)
          PopupMenuItem(
            value: 'video',
            child: ListTile(
              leading: Icon(
                _isVideoVisible ? Icons.videocam_off : Icons.videocam,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Video Referencia'),
              trailing: Switch(
                value: _isVideoVisible,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value) {
                    _initializeVideoPlayer(videoReference['url']);
                  } else {
                    setState(() => _isVideoVisible = false);
                  }
                },
              ),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'metronome',
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Metrónomo'),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              Navigator.pop(context);
              _showMetronomeSettings(context);
            },
          ),
        ),
        PopupMenuItem(
          value: 'transpose',
          child: ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Transposición'),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              Navigator.pop(context);
              _showTranspositionMenu(context);
            },
          ),
        ),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar canción'),
              onTap: () => _navigateToEditScreen(),
            ),
          ),
        PopupMenuItem(
          value: 'teleprompter',
          child: ListTile(
            leading: const Icon(Icons.slideshow),
            title: const Text('Modo presentación'),
            onTap: () => _navigateToTeleprompter(),
          ),
        ),
        PopupMenuItem<String>(
          value: 'info',
          child: ListTile(
            title: const Text('Información de la canción'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              Navigator.pop(context);
              _showSongInfoDialog();
            },
          ),
        ),
      ],
    );
  }

  void _showMetronomeSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.only(bottom: 20),
          child: SafeArea(
            child: GestureDetector(
              onTap: () {},
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: StatefulBuilder(
                  builder: (context, setSheetState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Configuración del Metrónomo',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      _buildBpmControls(),
                      const SizedBox(height: 30),
                      FilledButton.icon(
                        icon: Icon(
                          _isMetronomeActive ? Icons.stop : Icons.play_arrow,
                          size: 28,
                        ),
                        label: Text(_isMetronomeActive ? 'Detener' : 'Iniciar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          backgroundColor: _isMetronomeActive
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          if (_isMetronomeActive) {
                            _stopMetronome();
                          } else {
                            _startMetronome();
                          }
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTranspositionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SafeArea(
            child: GestureDetector(
              onTap: () {},
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Transposición',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.arrow_upward),
                      title: const Text('Subir medio tono'),
                      trailing: const Icon(Icons.keyboard_arrow_up),
                      onTap: () {
                        _transposeChords(true);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.arrow_downward),
                      title: const Text('Bajar medio tono'),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: () {
                        _transposeChords(false);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('Restaurar original'),
                      trailing: const Icon(Icons.refresh),
                      onTap: () {
                        _restoreOriginalChords();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isPlayingMetronome => _metronomeTimer != null;

  Future<void> _initializeMetronome() async {
    try {
      final audioCache = AudioCache(prefix: 'assets/audio/');
      final assetPath = await audioCache.load('click.wav');

      // Obtener el valor actualizado de Firestore
      final songDoc = await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .get();

      if (songDoc.exists) {
        final songData = songDoc.data() as Map<String, dynamic>;
        setState(() {
          _firestoreBpm =
              songData['tempo']?.toInt() ?? songData['bpm']?.toInt() ?? 0;
          _localBpm = null; // Resetear cualquier ajuste local
        });
      }

      await _metronomePlayer.setSourceAsset(assetPath.path);
      await _metronomePlayer.setPlaybackRate(1.0);
      await _metronomePlayer.setVolume(1.0);
      await _metronomePlayer.setReleaseMode(ReleaseMode.release);

      print('Metrónomo inicializado con BPM: $_firestoreBpm');
    } catch (e) {
      print('Error inicializando metrónomo: $e');
    }
  }

  // 2. Restaurar método del diálogo BPM
  void _showBpmDialog(BuildContext context, int currentBpm) {
    final controller = TextEditingController(text: currentBpm.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar BPM'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nuevo BPM',
            hintText: 'Ej: 120',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newBpm = int.tryParse(controller.text) ?? effectiveBpm;
              setState(() => _localBpm = newBpm);

              // Reiniciar metrónomo si está activo
              if (_isMetronomeActive) {
                _metronomeTimer?.cancel();
                _startMetronome();
              }

              Navigator.pop(context);
              _updateBpmInFirestore(newBpm);

              // Forzar actualización en el BottomSheet
              if (mounted) setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBpmInFirestore(int newBpm) async {
    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({'tempo': newBpm});

      // Sincronizar valor local con Firestore después de actualización exitosa
      if (mounted) {
        setState(() {
          _firestoreBpm = newBpm;
          _localBpm = null; // Resetear ajuste temporal
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar BPM: $e')),
        );
      }
    }
  }

  Stream<GroupRole> _getUserRole() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(GroupRole.member);

    return FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('memberships')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return GroupRole.member;
      return GroupRole.fromString(snapshot.data()?['role'] ?? 'member');
    });
  }

  Widget _buildMiniVideoPlayer() {
    if (!_isVideoVisible || _videoController == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _videoOffsetX,
      top: _videoOffsetY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _videoOffsetX = (_videoOffsetX + details.delta.dx)
                .clamp(0.0, MediaQuery.of(context).size.width - 200);
            _videoOffsetY = (_videoOffsetY + details.delta.dy)
                .clamp(0.0, MediaQuery.of(context).size.height - 112);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Stack(
            children: [
              _buildVideoContent(),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fast_rewind,
                          color: Colors.white, size: 18),
                      onPressed: () {
                        final newPosition = _videoController!.value.position -
                            const Duration(seconds: 10);
                        _videoController!.seekTo(newPosition);
                      },
                      tooltip: 'Retroceder 10 segundos',
                    ),
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fast_forward,
                          color: Colors.white, size: 18),
                      onPressed: () {
                        final newPosition = _videoController!.value.position +
                            const Duration(seconds: 10);
                        _videoController!.seekTo(newPosition);
                      },
                      tooltip: 'Adelantar 10 segundos',
                    ),
                    IconButton(
                      icon: const Icon(Icons.launch,
                          color: Colors.white, size: 18),
                      onPressed: _openInYouTube,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      onPressed: () => setState(() => _isVideoVisible = false),
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

  Widget _buildVideoContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 200,
        height: 112,
        child: YoutubePlayer(
          controller: _videoController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
          progressColors: const ProgressBarColors(
            playedColor: Colors.blueAccent,
            handleColor: Colors.blueAccent,
          ),
          onReady: () {
            _videoController!.updateValue(
              _videoController!.value.copyWith(
                isControlsVisible: false,
              ),
            );
          },
        ),
      ),
    );
  }

  void _initializeVideoPlayer(String videoUrl) {
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);
    if (videoId != null) {
      _videoController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
          disableDragSeek: true,
          controlsVisibleAtStart: false,
        ),
      );
      setState(() => _isVideoVisible = true);
    }
  }

  void _openInYouTube() async {
    final videoUrl = _songData['videoReference']['url'];
    if (await canLaunch(videoUrl)) {
      await launch(videoUrl);
    } else {
      SnackBarUtils.showSnackBar(context,
          message: 'No se pudo abrir YouTube', isError: true);
    }
  }

  void _handleChordTap(String chord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acorde seleccionado'),
        content: Text('Acorde: $chord'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Future<void> _initializeLyrics(String lyrics, String transposedLyrics) async {
    // Implementa la lógica para inicializar las letras
  }

  void _showPlaylistSongsSheet(BuildContext context) {
    if (widget.playlistSongs == null || widget.playlistSongs!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlistName ?? 'Canciones de la Playlist',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.playlistSongs != null)
                        Text(
                          '${widget.playlistSongs!.length} canciones',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildPlaylistSongsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSongsList() {
    return ListView.builder(
      itemCount: widget.playlistSongs?.length ?? 0,
      itemBuilder: (context, index) {
        final songId = widget.playlistSongs![index];
        final isCurrentSong = songId == widget.songId;

        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('songs').doc(songId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                title: const Text('Cargando...'),
                leading: const CircleAvatar(
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }

            final songData = snapshot.data!.data() as Map<String, dynamic>;
            final title = songData['title'] ?? 'Sin título';

            return ListTile(
              title: Text(
                title,
                style: TextStyle(
                  fontWeight:
                      isCurrentSong ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentSong
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: isCurrentSong
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: isCurrentSong
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                child: Text('${index + 1}'),
              ),
              trailing: isCurrentSong
                  ? Icon(Icons.play_arrow,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.chevron_right),
              onTap: isCurrentSong
                  ? () => Navigator.pop(context)
                  : () => _navigateToSong(songId, index),
            );
          },
        );
      },
    );
  }

  void _navigateToSong(String songId, int index) {
    Navigator.pop(context); // Cerrar el bottom sheet

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SongDetailsScreen(
          songId: songId,
          groupId: widget.groupId,
          playlistSongs: widget.playlistSongs,
          playlistId: widget.playlistId,
          playlistName: widget.playlistName,
        ),
      ),
    );
  }
}

class FullScreenLyricsEditor extends StatefulWidget {
  final String lyrics;
  final Function(String) onSave;

  const FullScreenLyricsEditor({
    super.key,
    required this.lyrics,
    required this.onSave,
  });

  @override
  FullScreenLyricsEditorState createState() => FullScreenLyricsEditorState();
}

class FullScreenLyricsEditorState extends State<FullScreenLyricsEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.lyrics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor Completo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSave(_controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LyricsInputField(
          controller: _controller,
          isFullScreen: true,
        ),
      ),
    );
  }
}
