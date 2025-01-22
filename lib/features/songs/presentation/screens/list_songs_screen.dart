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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Canciones del Grupo',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.more_horiz),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Canciones eliminadas'),
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
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text('Compartir canciones'),
                    onTap: () {
                      Navigator.pop(context);
                      _shareSongs();
                    },
                  ),
                  ListTile(
                    leading: Icon(_ascendingOrder
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    title: Text(
                        'Ordenar ${_ascendingOrder ? "descendente" : "ascendente"}'),
                    onTap: () {
                      setState(() {
                        _ascendingOrder = !_ascendingOrder;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
                    final song = songs[index]!;
                    final data = song.data() as Map<String, dynamic>;

                    return Dismissible(
                      key: Key(song.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final songTitle = data['title'] as String;
                        final songId = song.id;
                        setState(() {
                          _lastDeletedSongId = songId;
                          _lastDeletedSongTitle = songTitle;
                        });

                        await FirebaseFirestore.instance
                            .collection('songs')
                            .doc(songId)
                            .update({
                          'isActive': false,
                          'deletedAt': FieldValue.serverTimestamp(),
                        });

                        _showDeleteBanner(songTitle);
                        return true;
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SongDetailsScreen(
                                songId: song.id,
                                groupId: widget.group.id,
                              ),
                            ),
                          );
                        },
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
    if (user == null) return Stream.value([]);

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

    // Query para canciones archivadas del usuario actual
    final archivedQuery = FirebaseFirestore.instance
        .collection('songs')
        .where('groupId', isEqualTo: widget.group.id)
        .where('isActive', isEqualTo: false)
        .where('createdBy', isEqualTo: user.uid);

    // Combinar los resultados de las tres queries
    return Rx.combineLatest3(
      publishedQuery.snapshots(),
      draftsQuery.snapshots(),
      archivedQuery.snapshots(),
      (QuerySnapshot published, QuerySnapshot drafts, QuerySnapshot archived) {
        final allDocs = [...published.docs, ...drafts.docs, ...archived.docs];
        // Ordenar manualmente
        allDocs.sort((a, b) {
          final titleA = (a.data() as Map<String, dynamic>)['title'] as String;
          final titleB = (b.data() as Map<String, dynamic>)['title'] as String;
          return _ascendingOrder
              ? titleA.compareTo(titleB)
              : titleB.compareTo(titleA);
        });
        return allDocs;
      },
    );
  }

  Future<void> _shareSongs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where('groupId', isEqualTo: widget.group.id)
          .where('isActive', isEqualTo: true)
          .orderBy('title')
          .get();

      final songs = snapshot.docs
          .map((doc) =>
              SongModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      if (songs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay canciones para compartir'),
          ),
        );
        return;
      }

      // Crear texto formateado
      final buffer = StringBuffer();
      buffer.writeln('LISTA DE CANCIONES');
      buffer.writeln('Grupo: ${widget.group.name}');
      buffer.writeln(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      buffer.writeln('----------------------------------------');
      buffer.writeln('');

      for (final song in songs) {
        buffer.writeln('📝 ${song.title.toUpperCase()}');
        buffer.writeln('👤 Autor: ${song.author}');
        buffer.writeln('🎵 Clave: ${song.baseKey}');
        if (song.duration.isNotEmpty) {
          buffer.writeln('⏱️ Duración: ${song.duration}');
        }
        if (song.tags.isNotEmpty) {
          buffer.writeln('🏷️ Tags: ${song.tags.join(", ")}');
        }
        buffer.writeln('----------------------------------------');
      }

      buffer.writeln('');
      buffer.writeln('Total de canciones: ${songs.length}');
      buffer.writeln('');
      buffer.writeln('Compartido desde Chordly');

      await Share.share(
        buffer.toString(),
        subject: 'Lista de Canciones - ${widget.group.name}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: Colors.red,
        ),
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

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
