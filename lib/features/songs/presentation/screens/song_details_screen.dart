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
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class SongDetailsScreen extends ConsumerStatefulWidget {
  final String? songId;
  final String? groupId;
  final List<String>? playlistSongs;
  final int? currentIndex;

  const SongDetailsScreen({
    Key? key,
    required this.songId,
    required this.groupId,
    this.playlistSongs,
    this.currentIndex,
  }) : super(key: key);

  @override
  ConsumerState<SongDetailsScreen> createState() => _SongDetailsScreenState();
}

class _SongDetailsScreenState extends ConsumerState<SongDetailsScreen> {
  Stream<DocumentSnapshot> _songStream = const Stream.empty();
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _metronome = AudioPlayer();
  Timer? _metronomeTimer;
  bool _isPlayingMetronome = false;
  int? _soundId;
  int? _lastBeatTime;
  int _currentBpm = 0;
  YoutubePlayerController? _videoController;
  bool _isVideoVisible = false;
  double _videoOffsetX = 0;
  double _videoOffsetY = 0;
  late Map<String, dynamic> _songData;

  // Agregar getter para isLandscape
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  void initState() {
    super.initState();
    _isInitialized = false;
    _currentIndex = widget.currentIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);

    // Configurar el stream inmediatamente
    _songStream = FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .snapshots();

    _initMetronome();

    // Inicializar las letras y el tempo cuando se carga el documento
    _songStream.listen((snapshot) {
      if (mounted) {
        setState(() {
          _songData = snapshot.data() as Map<String, dynamic>;
          _originalLyrics = _songData['lyrics'] ?? '';
          _transposedLyrics = _songData['lyricsTranspose'] ?? _originalLyrics;
          _currentBpm =
              _songData['tempo']?.toInt() ?? _songData['bpm']?.toInt() ?? 0;
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _initMetronome() async {
    try {
      await _metronome.setSource(AssetSource('audio/click.wav'));
      await _metronome.setVolume(1.0);
      await _metronome.setReleaseMode(ReleaseMode.stop);
      print('Metrónomo inicializado');
    } catch (e) {
      print('Error al inicializar el metrónomo: $e');
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _pageController.dispose();
    _autoScrollController.dispose();
    _audioPlayer.dispose();
    _metronomeTimer?.cancel();
    _metronome.dispose();
    _videoController?.dispose();
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
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.playlistSongs!.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _isInitialized = false;
          // Resetear el estado de la canción
          _originalLyrics = '';
          _transposedLyrics = '';
          _isPlayingMetronome = false;
          _metronomeTimer?.cancel();
          _isVideoVisible = false;
          _videoController?.dispose();
          _videoController = null;
          _videoOffsetX = 0;
          _videoOffsetY = 0;
          _scale = 1.0;
          _fontSize = 16.0;
          _landscapeFontSize = 16.0;
        });

        // Actualizar el stream con la nueva canción
        _songStream = FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.playlistSongs![index])
            .snapshots();
      },
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
              return _buildErrorScreen('La canción no existe o fue eliminada');
            }

            final songData = snapshot.data!.data() as Map<String, dynamic>;

            // Inicializar las letras cuando se carga el documento
            if (!_isInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _originalLyrics = songData['lyrics'] ?? '';
                    _transposedLyrics =
                        songData['lyricsTranspose'] ?? _originalLyrics;
                    _currentBpm = songData['tempo']?.toInt() ??
                        songData['bpm']?.toInt() ??
                        0;
                    _isInitialized = true;
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
              songData['title'] ?? 'Sin título',
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            key,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
        ],
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
      Future.wait(
        widget.playlistSongs!.map(
          (id) => FirebaseFirestore.instance.collection('songs').doc(id).get(),
        ),
      ).catchError((e) {
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
                _currentBpm =
                    songData['tempo']?.toInt() ?? songData['bpm']?.toInt() ?? 0;
                _isInitialized = true;
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
              if (songData['videoReference'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.video_library,
                  'Video de referencia',
                  songData['videoReference']['notes'] ?? 'Sin notas',
                ),
              ],
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
      BuildContext context, IconData icon, String label, dynamic value) {
    if (label == 'BPM' && value is int && value > 0) {
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
          _buildBpmButton(context, value),
        ],
      );
    }
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
            value.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
            color: _isPlayingMetronome
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPlayingMetronome ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: _isPlayingMetronome
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$bpm BPM',
                style: TextStyle(
                  color: _isPlayingMetronome
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isPlayingMetronome) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _stopMetronome,
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMetronome() {
    if (_isPlayingMetronome) {
      _stopMetronome();
    } else {
      _startMetronome(_currentBpm);
    }
  }

  void _startMetronome(int bpm) {
    try {
      _currentBpm = bpm;
      _metronomeTimer?.cancel();

      final interval = (60000 / bpm).round();
      print('Iniciando metrónomo a $bpm BPM (intervalo: $interval ms)');

      _metronome.stop();
      _metronome.resume();

      setState(() => _isPlayingMetronome = true);

      _metronomeTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
        if (_isPlayingMetronome) {
          _metronome.stop();
          _metronome.resume();
        }
      });
    } catch (e) {
      print('Error: $e');
      _stopMetronome();
    }
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronome.stop();
    setState(() {
      _isPlayingMetronome = false;
      _currentBpm = _songData['tempo']?.toInt() ??
          _songData['bpm']?.toInt() ??
          0; // Restaurar el tempo original
    });
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
          groupId: widget.groupId!,
          isEditing: true,
        ),
      ),
    ).then((shouldRefresh) {
      if (shouldRefresh == true && mounted) {
        // Forzar actualización del stream
        setState(() {
          _isInitialized = false;
        });
      }
    });
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
          padding: const EdgeInsets.only(bottom: 60), // Espacio para la barra
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  minHeight: 48,
                  maxHeight: 48,
                  child: Container(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.95),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => _adjustBpm(-5),
                            tooltip: 'Disminuir BPM',
                            iconSize: 20,
                          ),
                          Text(
                            '$_currentBpm BPM',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _adjustBpm(5),
                            tooltip: 'Aumentar BPM',
                            iconSize: 20,
                          ),
                          IconButton(
                            icon: Icon(_isPlayingMetronome
                                ? Icons.stop
                                : Icons.play_arrow),
                            onPressed: _toggleMetronome,
                            tooltip:
                                _isPlayingMetronome ? 'Detener' : 'Iniciar',
                            iconSize: 20,
                          ),
                          const VerticalDivider(thickness: 1, width: 12),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: () => _transposeChords(false),
                            tooltip: 'Bajar medio tono',
                            iconSize: 20,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: () => _transposeChords(true),
                            tooltip: 'Subir medio tono',
                            iconSize: 20,
                          ),
                          const VerticalDivider(thickness: 1, width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _restoreOriginalChords,
                            tooltip: 'Restaurar original',
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                backgroundColor: section.color.withOpacity(0.1),
                foregroundColor: section.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: section.color.withOpacity(0.5),
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
              IconButton(
                icon: Icon(
                  _isPlayingMetronome ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _toggleMetronome,
              ),
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
                RemainingDuration(),
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
                    color: section.color.withOpacity(0.3),
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
                              color: section.color.withOpacity(0.3),
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
                              color: Theme.of(context).colorScheme.primary,
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
        PopupMenuItem(
          value: 'video',
          child: Row(
            children: [
              Icon(
                _isVideoVisible ? Icons.videocam_off : Icons.videocam,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Video Referencia'),
              const Spacer(),
              Checkbox(
                value: _isVideoVisible,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    if (value && hasVideo) {
                      _initializeVideoPlayer(videoReference['url']);
                    } else {
                      setState(() => _isVideoVisible = false);
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'transpose',
          child: PopupMenuButton<String>(
            child: const ListTile(
              leading: Icon(Icons.music_note),
              title: Text('Transposición'),
              trailing: Icon(Icons.arrow_right),
            ),
            onSelected: (value) {
              switch (value) {
                case 'up':
                  _transposeChords(true);
                  break;
                case 'down':
                  _transposeChords(false);
                  break;
                case 'reset':
                  _restoreOriginalChords();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'up',
                child: ListTile(
                  leading: Icon(Icons.arrow_upward),
                  title: Text('Subir medio tono'),
                ),
              ),
              const PopupMenuItem(
                value: 'down',
                child: ListTile(
                  leading: Icon(Icons.arrow_downward),
                  title: Text('Bajar medio tono'),
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Restaurar original'),
                ),
              ),
            ],
          ),
        ),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar canción'),
              onTap: () => _navigateToEdit(context),
            ),
          ),
        PopupMenuItem(
          value: 'teleprompter',
          child: ListTile(
            leading: const Icon(Icons.slideshow),
            title: const Text('Modo presentación'),
            onTap: () => _showTeleprompterMode(context, songData),
          ),
        ),
      ],
    );
  }

  void _adjustBpm(int delta) {
    final newBpm = (_currentBpm + delta).clamp(40, 240);
    setState(() => _currentBpm = newBpm);
    if (_isPlayingMetronome) {
      _startMetronome(newBpm);
    }
  }

  Widget _buildChordText(String text) {
    final chordRegex = RegExp(r'\(([^)]+)\)');
    final matches = chordRegex.allMatches(text);
    int lastEnd = 0;
    final spans = <TextSpan>[];

    for (final match in matches) {
      // Texto antes del acorde
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 16,
          ),
        ));
      }

      // Parentesis y contenido
      spans.add(TextSpan(
        text: '(',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 16,
        ),
      ));
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          backgroundColor: Colors.blue.shade50,
          fontFamily: 'RobotoMono',
        ),
      ));
      spans.add(TextSpan(
        text: ')',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 16,
        ),
      ));

      lastEnd = match.end;
    }

    // Texto restante después del último acorde
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 16,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _openFullScreenEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenLyricsEditor(
          lyrics: _transposedLyrics,
          onSave: (newLyrics) {
            setState(() => _transposedLyrics = newLyrics);
            _updateFirestoreLyrics(newLyrics);
          },
        ),
      ),
    );
  }

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
              final newBpm = int.tryParse(controller.text) ?? currentBpm;
              setState(() => _currentBpm = newBpm);
              Navigator.pop(context);
              _updateBpmInFirestore(newBpm);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar BPM: $e')),
        );
      }
    }
  }

  Future<void> _updateFirestoreLyrics(String newLyrics) async {
    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({
        'lyrics': newLyrics,
        'lyricsTranspose': newLyrics,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar cambios: $e')),
        );
      }
    }
  }

  // Método para determinar si hay transposición activa
  bool get hasActiveTransposition => _transposedLyrics != _originalLyrics;
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
