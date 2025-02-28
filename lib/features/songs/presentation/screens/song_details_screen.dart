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
  final List<String>? playlistSongs;
  final int currentIndex;
  final bool fromPlaylist;

  const SongDetailsScreen({
    super.key,
    required this.songId,
    required this.groupId,
    this.playlistSongs,
    this.currentIndex = 0,
    this.fromPlaylist = false,
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
  late PageController _pageController;
  int _currentIndex = 0;
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

  // Agregar getter para isLandscape
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // 1. Agregar variable _currentBpm como getter calculado
  int get effectiveBpm => _localBpm ?? _firestoreBpm;

  // 1. Restaurar getter de transposición
  bool get hasActiveTransposition => _transposedLyrics != _originalLyrics;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Configurar stream principal
    _initializeSongStream();

    _metronomePlayer = AudioPlayer();
    _initializeMetronome();
  }

  // 2. Método separado para inicializar el stream
  void _initializeSongStream() {
    _songStream = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .snapshots();

    _songStream.listen((DocumentSnapshot snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data()! as Map<String, dynamic>;
        setState(() {
          _songData = data;
          _firestoreBpm = (data['tempo'] as num?)?.toInt() ?? 0;
          _originalLyrics = data['lyrics']?.toString() ?? '';
          _transposedLyrics =
              data['lyricsTranspose']?.toString() ?? _originalLyrics;
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _pageController.dispose();
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

    // Usar _originalLyrics como base, a menos que haya una transposición activa
    final lyricsToDisplay =
        hasActiveTransposition ? _transposedLyrics : _originalLyrics;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: RichText(
        key: ValueKey(
            lyricsToDisplay), // Cambiar la clave para forzar la animación
        text: _buildTextSpans(lyricsToDisplay, actualFontSize),
        textAlign: TextAlign.left,
      ),
    );
  }

  TextSpan _buildTextSpans(String lyrics, double fontSize) {
    final chordRegex = RegExp(r'\(([^)]+)\)');
    final referenceRegex = RegExp(r'_([^_]+)_');

    // Dividir primero por acordes
    final parts = lyrics.split(chordRegex);
    final chords =
        chordRegex.allMatches(lyrics).map((m) => m.group(1)!).toList();

    List<TextSpan> textSpans = [];

    for (int i = 0; i < parts.length; i++) {
      // Procesar el texto para referencias (texto entre guiones bajos)
      final textParts = parts[i].split(referenceRegex);
      final references =
          referenceRegex.allMatches(parts[i]).map((m) => m.group(1)!).toList();

      // Agregar partes del texto y referencias
      for (int j = 0; j < textParts.length; j++) {
        // Agregar texto normal
        if (textParts[j].isNotEmpty) {
          textSpans.add(TextSpan(
            text: textParts[j],
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ));
        }

        // Agregar referencia si existe
        if (j < references.length) {
          textSpans.add(TextSpan(
            text: references[j],
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.amber[700],
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ));
        }
      }

      // Agregar acorde si existe
      if (i < chords.length) {
        textSpans.add(TextSpan(
          text: '(${chords[i]})',
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ));
      }
    }

    return TextSpan(children: textSpans);
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

      setState(() {
        _transposedLyrics = newTransposedLyrics;
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
    // Si no hay playlist, mostrar vista normal
    if (widget.playlistSongs == null) {
      return _buildSingleSongView();
    }

    // Si hay playlist, envolver en PageView para permitir deslizar
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return true;
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: widget.fromPlaylist
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.playlistSongs!.length,
            onPageChanged: _handlePageChange,
            itemBuilder: (context, index) {
              // Asegurarnos de que estamos usando el ID correcto de la canción
              final currentSongId = widget.playlistSongs![index];

              return StreamBuilder<DocumentSnapshot>(
                // Usar un stream específico para cada canción
                stream: FirebaseFirestore.instance
                    .collection('songs')
                    .doc(currentSongId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.data!.exists) {
                    return _buildErrorScreen(
                        'La canción no existe o fue eliminada');
                  }

                  final songData =
                      snapshot.data!.data() as Map<String, dynamic>;

                  // Inicializar las letras cuando se carga el documento
                  if (!_isInitialized) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _originalLyrics = songData['lyrics'] ?? '';
                          _transposedLyrics =
                              songData['lyricsTranspose'] ?? _originalLyrics;
                          _firestoreBpm = songData['tempo']?.toInt() ??
                              songData['bpm']?.toInt() ??
                              0;
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
                      final canEdit = userRole == GroupRole.admin ||
                          userRole == GroupRole.editor;

                      return Scaffold(
                        backgroundColor: isLandscape ? Colors.black : null,
                        appBar: isLandscape
                            ? null
                            : _buildAppBar(context, songData, canEdit),
                        body: Stack(
                          children: [
                            _buildSongContent(songData),
                            if (isLandscape)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _buildLandscapeControls(),
                              ),
                            _buildVideoPlayer(),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          _buildVideoPlayer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Map<String, dynamic> songData,
    bool canEdit,
  ) {
    final key = songData['baseKey'] ?? 'N/A';
    final bpm = songData['tempo']?.toString() ?? 'N/A';

    return AppBar(
      title: Row(
        children: [
          Expanded(
            child: Text(
              songData['title'] ?? 'Detalles de canción',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              overflow: TextOverflow.ellipsis,
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
      actions: [
        if (widget.fromPlaylist && widget.playlistSongs != null)
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: _currentIndex > 0
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
            ),
            onPressed: _currentIndex > 0
                ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
        if (widget.fromPlaylist && widget.playlistSongs != null)
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _currentIndex < widget.playlistSongs!.length - 1
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
            ),
            onPressed: _currentIndex < widget.playlistSongs!.length - 1
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : null,
          ),
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
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getSongsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final song = snapshot.data![index];
            final data = song.data() as Map<String, dynamic>;
            final isSelected = index == _currentIndex;

            return ListTile(
              selected: isSelected,
              leading: isSelected
                  ? Icon(Icons.play_arrow,
                      color: Theme.of(context).colorScheme.primary)
                  : Text('${index + 1}',
                      style: Theme.of(context).textTheme.bodyLarge),
              title: Text(
                data['title'],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(data['author'] ?? ''),
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                // Cerrar bottom sheet si está abierto
                if (MediaQuery.of(context).size.width <= 600) {
                  Navigator.pop(context);
                }
              },
            );
          },
        );
      },
    );
  }

  Stream<List<DocumentSnapshot>> _getSongsStream() {
    return Stream.fromFuture(
      Future.wait(widget.playlistSongs!
              .map(
                (id) => FirebaseFirestore.instance
                    .collection('songs')
                    .doc(id)
                    .get(),
              )
              .cast<Future<DocumentSnapshot>>())
          .catchError((e) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            message: 'Error al cargar las canciones: $e',
            isError: true,
          );
        }
        return [];
      }),
    );
  }

  Widget _buildSingleSongView() {
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
        final newTransposedLyrics = songData['lyricsTranspose'] ?? newLyrics;

        // Actualizar el estado local cuando los datos cambian
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
                  if (isLandscape)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildLandscapeControls(),
                    ),
                  _buildVideoPlayer(),
                ],
              ),
            );
          },
        );
      },
    );
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
                  margin: EdgeInsets.zero, // Eliminar margen de la Card
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.zero, // Eliminar bordes redondeados
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
        // Contenedor para el encabezado
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
              _buildInfoRow('Creada por:', songData['author'] ?? 'Desconocido'),
              _buildInfoRow(
                  'Fecha creación:',
                  songData['createdAt'] != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(songData['createdAt'].toDate())
                      : 'No disponible'),
              _buildInfoRow('Última edición por:',
                  songData['lastUpdatedBy'] ?? 'Desconocido'),
              _buildInfoRow(
                  'Fecha última edición:',
                  songData['updatedAt'] != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(songData['updatedAt'].toDate())
                      : 'No disponible'),
              const SizedBox(height: 16),
              const Text('Colaboradores:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...?songData['collaborators']
                  ?.where((c) => c != null)
                  .map((c) => Text('• $c')),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeleprompterScreen(
          title: songData['title'],
          lyrics: _transposedLyrics,
          playlistSongs: widget.playlistSongs,
          currentIndex: _currentIndex,
        ),
      ),
    );
  }

  Widget _buildSongContent(Map<String, dynamic> songData) {
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
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    section.color?.withOpacity(0.1) ?? Colors.transparent,
                foregroundColor: section.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color:
                        section.color?.withOpacity(0.5) ?? Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              onPressed: () => Scrollable.ensureVisible(
                keys[index].currentContext!,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              ),
              child: Text(
                section.type.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeControls() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.white),
                onPressed: () => _transposeChords(false),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: () => _transposeChords(true),
              ),
              const VerticalDivider(color: Colors.white30),
              IconButton(
                icon: const Icon(Icons.text_decrease, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _landscapeFontSize =
                        (_landscapeFontSize - 2).clamp(12.0, 32.0);
                  });
                },
              ),
              Text(
                '${_landscapeFontSize.round()}',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _landscapeFontSize =
                        (_landscapeFontSize + 2).clamp(12.0, 32.0);
                  });
                },
              ),
              const VerticalDivider(color: Colors.white30),
              _buildBpmControls(),
              const VerticalDivider(color: Colors.white30),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _restoreOriginalChords,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modificar _getUserRole para usar el groupId resuelto
  Stream<GroupRole> _getUserRole() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(GroupRole.member);

    final groupId = _resolvedGroupId ?? widget.groupId;
    if (groupId == null || groupId.isEmpty)
      return Stream.value(GroupRole.member);

    return FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return GroupRole.member;
      return GroupRole.fromString(snapshot.data()?['role'] ?? 'member');
    });
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoVisible || _videoController == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16 + _videoOffsetY,
      right: 16 + _videoOffsetX,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _videoOffsetX -= details.delta.dx;
            _videoOffsetY -= details.delta.dy;
          });
        },
        child: Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(
              controller: _videoController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Theme.of(context).colorScheme.primary,
              actionsPadding: const EdgeInsets.all(4),
              bottomActions: [
                CurrentPosition(),
                ProgressBar(
                  isExpanded: true,
                  colors: ProgressBarColors(
                    playedColor: Theme.of(context).colorScheme.primary,
                    handleColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
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
          enableCaption: false,
          useHybridComposition: true,
          forceHD: false,
          showLiveFullscreenButton: false,
          disableDragSeek: false,
          hideControls: false,
          controlsVisibleAtStart: true,
          mute: false,
        ),
      );
      setState(() {
        _isVideoVisible = true;
        _videoOffsetX = 0;
        _videoOffsetY = 0;
      });
    }
  }

  Widget _buildVideoReferenceButton(Map<String, dynamic> songData) {
    final videoReference = songData['videoReference'];
    if (videoReference == null) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(_isVideoVisible ? Icons.close : Icons.video_library),
      tooltip: _isVideoVisible ? 'Cerrar video' : 'Ver video de referencia',
      onPressed: () {
        if (!_isVideoVisible) {
          _initializeVideoPlayer(videoReference['url']);
        } else {
          setState(() {
            _isVideoVisible = false;
            _videoController?.dispose();
            _videoController = null;
          });
        }
      },
    );
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
            return Container(
              margin: const EdgeInsets.only(top: 24),
              child: Card(
                key: keys[index],
                elevation: 3,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color:
                        section.color?.withOpacity(0.3) ?? Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -20,
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
                          top: 24, bottom: 20, left: 20, right: 20),
                      child: Text(
                        section.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
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
        PopupMenuItem(
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
      isDismissible: false,
      enableDrag: true,
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width * 0.95,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
    );
  }

  void _showTranspositionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SafeArea(
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
    );
  }

  bool get _isPlayingMetronome => _metronomeTimer != null;

  void _handlePageChange(int index) {
    setState(() {
      _currentIndex = index;
      _isInitialized = false;
      _originalLyrics = '';
      _transposedLyrics = '';
      _metronomeTimer?.cancel();
      _isVideoVisible = false;
      _videoController?.dispose();
      _videoController = null;
      _videoOffsetX = 0;
      _videoOffsetY = 0;
      _scale = 1.0;
      _fontSize = 16.0;
      _landscapeFontSize = 16.0;
      _localBpm = null;
    });
    _initializeSongStream();
  }

  Future<void> _initializeMetronome() async {
    try {
      final url = await AudioCache(prefix: 'assets/audio/').load('click.wav');
      await _metronomePlayer.setSourceUrl(url.path);
      await _metronomePlayer.setPlaybackRate(1.0);
      await _metronomePlayer.setVolume(1.0);
      await _metronomePlayer.setReleaseMode(ReleaseMode.release);
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

  void _showSongInfoDialog() async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Obtener nombres de usuarios
    final creatorName = await _getUserName(
        _songData['creatorUserId'] ?? _songData['createdBy']);
    final lastEditorName = await _getUserName(_songData['lastUpdatedBy']);

    // Obtener colaboradores
    final collaborators = await Future.wait(
        (_songData['collaborators'] as List<dynamic>? ?? [])
            .map((uid) => _getUserName(uid.toString()))
            .toList());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Información detallada',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección: Información Básica
              _buildInfoSectionTitle('Información básica'),
              _buildInfoRow('Título', _songData['title'] ?? 'Sin título'),
              _buildInfoRow('Autor', _songData['author'] ?? 'Desconocido'),
              _buildInfoRow(
                  'Estado',
                  _songData['status'] == 'publicado'
                      ? 'Publicado'
                      : 'Borrador ⚫'),

              const SizedBox(height: 12),

              // Sección: Datos Musicales
              _buildInfoSectionTitle('Datos musicales'),
              _buildInfoRow('Duración',
                  _songData['duration']?.toString().padLeft(4, '0') ?? '00:00'),
              _buildInfoRow(
                  'BPM', '${_songData['tempo'] ?? _songData['bpm'] ?? '--'}'),
              _buildInfoRow('Tonalidad base',
                  _songData['baseKey']?.toUpperCase() ?? 'No definida'),

              const SizedBox(height: 12),

              // Sección: Multimedia
              if (_songData['videoReference'] != null) ...[
                _buildInfoSectionTitle('Referencia multimedia'),
                if (_songData['videoReference']?['url'] != null)
                  _buildInfoRow('Video', _songData['videoReference']?['url']),
                if (_songData['videoReference']?['notes'] != null)
                  _buildInfoRow(
                      'Notas del video', _songData['videoReference']?['notes']),
              ],

              const SizedBox(height: 12),

              // Sección: Metadatos
              _buildInfoSectionTitle('Metadatos'),
              _buildInfoRow('Creada por', creatorName ?? 'Desconocido'),
              _buildInfoRow(
                  'Fecha creación', _formattedDate(_songData['createdAt'])),
              _buildInfoRow(
                  'Última edición por', lastEditorName ?? 'Desconocido'),
              _buildInfoRow('Fecha última edición',
                  _formattedDate(_songData['updatedAt'])),

              const SizedBox(height: 12),

              // Sección: Colaboración
              _buildInfoSectionTitle('Colaboración'),
              if ((_songData['collaborators'] as List?)?.isNotEmpty ??
                  false) ...[
                _buildInfoRow('Total colaboradores',
                    '${_songData['collaborators']?.length ?? 0}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (_songData['collaborators'] as List)
                      .map((uid) => _buildUserChip(uid))
                      .toList(),
                ),
              ] else
                _buildInfoRow(
                    'Colaboradores', 'No hay colaboradores registrados'),

              const SizedBox(height: 12),

              // Sección: Tags
              _buildInfoSectionTitle('Etiquetas'),
              if ((_songData['tags'] as List?)?.isNotEmpty ?? false)
                Wrap(
                  spacing: 8,
                  children: (_songData['tags'] as List)
                      .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                )
              else
                _buildInfoRow('Etiquetas', 'Sin etiquetas asignadas'),
            ],
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Cerrar diálogo de información',
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserName(String? userId) async {
    if (userId == null) return null;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['displayName'] ?? 'Usuario desconocido';
  }

  String _formattedDate(dynamic timestamp) => timestamp != null
      ? DateFormat("dd MMM y • HH:mm").format((timestamp as Timestamp).toDate())
      : 'No registrada';

  Widget _buildUserChip(String userId) => FutureBuilder<String?>(
        future: _getUserName(userId),
        builder: (context, snapshot) => Chip(
          avatar: const Icon(Icons.person_outline, size: 18),
          label: Text(snapshot.data ?? 'Usuario desconocido'),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _buildInfoSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
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
