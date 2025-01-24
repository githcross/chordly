import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/delegates/song_search_delegate.dart';
import 'package:chordly/features/songs/presentation/screens/deleted_songs_screen.dart';
import 'package:chordly/features/songs/providers/songs_provider.dart';
import 'package:chordly/features/songs/presentation/screens/song_details_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:chordly/features/auth/providers/auth_provider.dart';
import 'package:chordly/core/theme/text_styles.dart';
import 'package:chordly/features/songs/presentation/screens/add_song_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ListSongsScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const ListSongsScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<ListSongsScreen> createState() => _ListSongsScreenState();
}

class _ListSongsScreenState extends ConsumerState<ListSongsScreen> {
  bool _ascendingOrder = true;
  Set<String> _selectedTags = {};
  String? _lastDeletedSongId;
  String? _lastDeletedSongTitle;
  OverlayEntry? _overlayEntry;
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;
  Set<String> _selectedSongs = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedSongs.length} seleccionados'
              : 'Canciones',
          style: AppTextStyles.appBarTitle(context),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedSongs.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _selectedSongs.isNotEmpty
                  ? () => _shareSongs(_selectedSongs.toList())
                  : null,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                  _ascendingOrder ? Icons.arrow_upward : Icons.arrow_downward),
              tooltip: _ascendingOrder
                  ? 'Ordenar descendente'
                  : 'Ordenar ascendente',
              onPressed: () {
                setState(() {
                  _ascendingOrder = !_ascendingOrder;
                });
              },
            ),
            IconButton(
              icon: Badge(
                isLabelVisible: _selectedTags.isNotEmpty,
                label: Text(_selectedTags.length.toString()),
                child: const Icon(Icons.tag),
              ),
              tooltip: 'Filtrar por tags',
              onPressed: _showTagFilter,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar canciones',
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: SongSearchDelegate(groupId: widget.group.id),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getSongsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data?.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Filtrar por término de búsqueda si existe
                  if (_searchController.text.isNotEmpty) {
                    final searchTerm = _searchController.text.toLowerCase();
                    final title = (data['title'] as String).toLowerCase();
                    return title.contains(searchTerm);
                  }
                  return true;
                }).toList();

                if (songs == null || songs.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron canciones'),
                  );
                }

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final data = song.data() as Map<String, dynamic>;
                    final isSelected = _selectedSongs.contains(song.id);

                    return Dismissible(
                      key: Key(song.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmar eliminación'),
                            content: Text(
                                '¿Estás seguro de que quieres eliminar "${data['title']}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('CANCELAR'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('ELIMINAR'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        _lastDeletedSongId = song.id;
                        _lastDeletedSongTitle = data['title'];

                        await FirebaseFirestore.instance
                            .collection('songs')
                            .doc(song.id)
                            .update({'isActive': false});

                        _showDeleteBanner(data['title']);
                      },
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value!) {
                                      _selectedSongs.add(song.id);
                                    } else {
                                      _selectedSongs.remove(song.id);
                                    }
                                  });
                                },
                              )
                            : null,
                        title: Text(
                          data['title'] as String,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        subtitle: Text(
                          data['author'] as String? ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        onTap: _isSelectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSongs.remove(song.id);
                                  } else {
                                    _selectedSongs.add(song.id);
                                  }
                                });
                              }
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SongDetailsScreen(
                                      songId: song.id,
                                      groupId: widget.group.id,
                                    ),
                                  ),
                                ),
                        onLongPress: !_isSelectionMode
                            ? () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedSongs.add(song.id);
                                });
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<QueryDocumentSnapshot>> _getSongsStream() {
    final user = ref.read(authProvider).value;
    if (user == null) return const Stream.empty();

    // Query para canciones publicadas
    final publishedQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'publicado');

    // Query para borradores del usuario actual
    final draftsQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'borrador')
        .where('createdBy', isEqualTo: user.uid);

    // Combinar los streams y ordenar
    return Rx.combineLatest2(
      publishedQuery.snapshots(),
      draftsQuery.snapshots(),
      (QuerySnapshot published, QuerySnapshot drafts) {
        final allDocs = [...published.docs, ...drafts.docs];
        allDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTitle = aData['title'] as String;
          final bTitle = bData['title'] as String;
          return _ascendingOrder
              ? aTitle.compareTo(bTitle)
              : bTitle.compareTo(aTitle);
        });
        return allDocs;
      },
    );
  }

  Future<void> _shareSongs(List<String> songIds) async {
    try {
      if (songIds.isEmpty) return;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfPath = '${tempDir.path}/songs_$timestamp.pdf';

      // Obtener datos de las canciones
      final songs = await Future.wait(
        songIds.map((id) =>
            FirebaseFirestore.instance.collection('songs').doc(id).get()),
      );

      // Crear y guardar el PDF
      final document = PdfDocument();
      _createPdfDocument(document, songs);
      final List<int> bytes = await document.save();
      await File(pdfPath).writeAsBytes(bytes);
      document.dispose();

      // Compartir el PDF
      await Share.shareFiles([pdfPath], text: 'Canciones compartidas');

      setState(() {
        _isSelectionMode = false;
        _selectedSongs.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  void _createPdfDocument(PdfDocument document, List<DocumentSnapshot> songs) {
    // Configurar estilo del documento
    final PdfStandardFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final PdfStandardFont subtitleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14);
    final PdfStandardFont contentFont =
        PdfStandardFont(PdfFontFamily.helvetica, 12);

    for (var song in songs) {
      final data = song.data() as Map<String, dynamic>;
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      final Rect bounds = Rect.fromLTWH(40, 40, page.getClientSize().width - 80,
          page.getClientSize().height - 80);

      // Agregar título
      graphics.drawString(
        data['title'],
        titleFont,
        bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 30),
      );

      // Agregar autor
      graphics.drawString(
        'Autor: ${data['author']}',
        subtitleFont,
        bounds: Rect.fromLTWH(bounds.left, bounds.top + 40, bounds.width, 20),
      );

      // Agregar letra
      graphics.drawString(
        data['lyrics'],
        contentFont,
        bounds: Rect.fromLTWH(
            bounds.left, bounds.top + 80, bounds.width, bounds.height - 80),
        format: PdfStringFormat(lineSpacing: 5),
      );
    }
  }

  Future<void> _showTagFilter() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    // Obtener todas las canciones publicadas y borradores del usuario
    final publishedSnapshot = await FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'publicado')
        .get();

    final draftsSnapshot = await FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'borrador')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    // Combinar los documentos
    final allDocs = [...publishedSnapshot.docs, ...draftsSnapshot.docs];

    // Extraer todos los tags únicos
    final allTags = allDocs.fold<Set<String>>(
      {},
      (tags, doc) {
        final songTags = List<String>.from(doc.data()['tags'] ?? []);
        return tags..addAll(songTags);
      },
    ).toList();

    if (!mounted) return;

    // Mostrar diálogo de selección de tags
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por tags'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTags.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteBanner(String songTitle) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se eliminó "$songTitle"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('songs')
                          .doc(_lastDeletedSongId)
                          .update({'isActive': true});
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: const Text('DESHACER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Agregar canción'),
              onTap: () {
                Navigator.pop(context);
                _addSong(context);
              },
            ),
            /*ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartir lista'),
              onTap: () {
                Navigator.pop(context);
                _shareSongs(_selectedSongs.toList());
              },
            ),*/
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Ver canciones eliminadas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeletedSongsScreen(
                      group: widget.group,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSong(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSongScreen(groupId: widget.group.id),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
