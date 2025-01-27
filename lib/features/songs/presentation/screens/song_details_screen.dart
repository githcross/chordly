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
    final textColor = isLandscape
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color;
    final chordColor = isLandscape ? Colors.lightBlue.shade300 : Colors.blue;
    final actualFontSize = fontSize ?? _fontSize;

    final chordRegex = RegExp(r'\(([^)]+)\)');
    final referenceRegex = RegExp(r'_([^_]+)_');

    // Dividir primero por acordes
    final parts = _transposedLyrics.split(chordRegex);
    final chords = chordRegex
        .allMatches(_transposedLyrics)
        .map((m) => m.group(1)!)
        .toList();

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
              fontSize: actualFontSize,
              color: textColor,
              height: 1.5,
            ),
          ));
        }

        // Agregar referencia si existe
        if (j < references.length) {
          textSpans.add(TextSpan(
            text: references[j],
            style: TextStyle(
              fontSize: actualFontSize,
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

    // Actualizar Firestore
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

    // Actualizar Firestore
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
    return Stack(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: _songStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('Error en StreamBuilder: ${snapshot.error}');
              return _buildErrorScreen('Error al cargar la canción');
            }

            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!snapshot.data!.exists) {
              return _buildErrorScreen('La canción no existe o fue eliminada');
            }

            final songData = snapshot.data!.data() as Map<String, dynamic>;

            // Inicializar las letras cuando se carga el documento
            if (!_isInitialized) {
              _originalLyrics = songData['lyrics'] ?? '';
              _transposedLyrics =
                  songData['lyricsTranspose'] ?? songData['lyrics'] ?? '';
              _isInitialized = true;
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
                      if (!isLandscape && _isPlayingMetronome)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildBpmControls(),
                        ),
                      _buildVideoPlayer(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Map<String, dynamic> songData,
    bool canEdit,
  ) {
    return AppBar(
      title: Text(songData['title'] ?? 'Sin título'),
      actions: [
        _buildVideoReferenceButton(songData),
        // Menú de transposición
        PopupMenuButton<String>(
          tooltip: 'Transposición',
          icon: const Icon(Icons.music_note),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'up',
              child: Row(
                children: [
                  Icon(Icons.arrow_upward,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Subir medio tono'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'down',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Bajar medio tono'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.refresh,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Restaurar acordes'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'up':
                _transposeChords(true);
                break;
              case 'down':
                _transposeChords(false);
                break;
              case 'restore':
                _restoreOriginalChords();
                break;
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.slideshow),
          tooltip: 'Telepromter',
          onPressed: () => _showTeleprompterMode(context, songData),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                if (canEdit) {
                  _navigateToEdit(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No tienes permisos para editar canciones'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                break;
              case 'info':
                _showInfoDialog(context, songData);
                break;
            }
          },
          itemBuilder: (context) => [
            if (canEdit)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('Información'),
                ],
              ),
            ),
          ],
        ),
      ],
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
      ),
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
                _isInitialized = true;
              });
            }
          });
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
    final List<Widget> rowChildren = [
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
    ];

    if (_isPlayingMetronome) {
      rowChildren.addAll([
        const SizedBox(width: 8),
        InkWell(
          onTap: _stopMetronome,
          child: Icon(
            Icons.close,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ]);
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: () => _toggleMetronome(bpm),
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
            children: rowChildren,
          ),
        ),
      ),
    );
  }

  void _toggleMetronome(int bpm) {
    if (_isPlayingMetronome) {
      _stopMetronome();
    } else {
      _currentBpm = bpm;
      _startMetronome(bpm);
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
    setState(() => _isPlayingMetronome = false);
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

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSongScreen(
          songId: widget.songId!,
          groupId: widget.groupId!,
        ),
      ),
    );

    // Si hubo cambios, forzar actualización del estado
    if (result == true && mounted) {
      setState(() {
        _isInitialized = false; // Esto forzará una recarga de los datos
      });
    }
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isLandscape ? Colors.black : null,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!isLandscape)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                minHeight: 48,
                maxHeight: 48,
                child: Container(
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        label: Text(
                          songData['baseKey'] ?? 'No especificada',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: isLandscape ? 16 : 0,
                bottom: isLandscape
                    ? 96
                    : _isPlayingMetronome
                        ? 96
                        : 16,
              ),
              child: _buildHighlightedLyrics(
                context,
                isLandscape: isLandscape,
                fontSize: isLandscape ? _landscapeFontSize : _fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmControls() {
    if (!_isPlayingMetronome) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  final newBpm = _currentBpm - 5;
                  if (newBpm > 0) {
                    _startMetronome(newBpm);
                  }
                },
              ),
              Text(
                '$_currentBpm BPM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _startMetronome(_currentBpm + 5),
              ),
            ],
          ),
        ),
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
              // Controles de tonalidad
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.white),
                onPressed: () => _transposeChords(false),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: () => _transposeChords(true),
              ),
              const VerticalDivider(color: Colors.white30),

              // Controles de fuente
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

              // Control de BPM
              if (_currentBpm > 0) ...[
                IconButton(
                  icon: Icon(
                    _isPlayingMetronome ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_isPlayingMetronome) {
                      _stopMetronome();
                    } else {
                      _startMetronome(_currentBpm);
                    }
                  },
                ),
                if (_isPlayingMetronome)
                  Text(
                    '$_currentBpm BPM',
                    style: const TextStyle(color: Colors.white),
                  ),
              ],

              // Restaurar acordes
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
}
