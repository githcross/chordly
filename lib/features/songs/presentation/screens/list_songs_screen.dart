import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/songs/models/song_model.dart';
import 'package:chordly/features/songs/presentation/delegates/song_search_delegate.dart';
import 'package:chordly/features/songs/presentation/screens/deleted_songs_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canciones del Grupo'),
        actions: [
          // Botón para ver canciones eliminadas
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Canciones eliminadas',
            onPressed: () {
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
          // Botón para compartir PDF
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir canciones',
            onPressed: _shareSongs,
          ),
          // Botón para ordenar
          IconButton(
            icon: Icon(
                _ascendingOrder ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip:
                'Ordenar ${_ascendingOrder ? "descendente" : "ascendente"}',
            onPressed: () {
              setState(() {
                _ascendingOrder = !_ascendingOrder;
              });
            },
          ),
          // Botón para filtrar por tags
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedTags.isNotEmpty,
              label: Text(_selectedTags.length.toString()),
              child: const Icon(Icons.tag),
            ),
            tooltip: 'Filtrar por tags',
            onPressed: _showTagFilter,
          ),
          // Botón de búsqueda
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('songs')
            .where('groupId', isEqualTo: widget.group.id)
            .where('isActive', isEqualTo: true)
            .orderBy('title', descending: !_ascendingOrder)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final songs = snapshot.data!.docs.map((doc) {
            return SongModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          // Filtrar por tags seleccionados
          if (_selectedTags.isNotEmpty) {
            songs.removeWhere(
                (song) => !song.tags.any((tag) => _selectedTags.contains(tag)));
          }

          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay canciones disponibles'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return Dismissible(
                key: Key(song.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar eliminación'),
                      content:
                          Text('¿Desea eliminar la canción "${song.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) => _inactivateSong(song),
                child: ListTile(
                  title: Text(song.title),
                  subtitle: Text(song.author),
                  trailing: Wrap(
                    spacing: 8,
                    children: song.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ))
                        .toList(),
                  ),
                  onTap: () {
                    // TODO: Navegar a la vista detallada de la canción
                  },
                ),
              );
            },
          );
        },
      ),
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
    try {
      // Obtener todos los tags disponibles
      final tagsDoc = await FirebaseFirestore.instance
          .collection('tags')
          .doc('default')
          .get();

      final availableTags = List<String>.from(tagsDoc.data()?['tags'] ?? []);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Filtrar por Tags'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
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
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar tags: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _inactivateSong(SongModel song) async {
    try {
      await FirebaseFirestore.instance.collection('songs').doc(song.id).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Canción eliminada'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('songs')
                  .doc(song.id)
                  .update({
                'isActive': true,
                'deletedAt': FieldValue.delete(),
              });
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
