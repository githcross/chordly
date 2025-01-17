import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:chordly/features/songs/models/song_model.dart';

class DeletedSongsScreen extends ConsumerStatefulWidget {
  final GroupModel group;

  const DeletedSongsScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<DeletedSongsScreen> createState() => _DeletedSongsScreenState();
}

class _DeletedSongsScreenState extends ConsumerState<DeletedSongsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canciones Eliminadas'),
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Las canciones se eliminarán permanentemente después de 7 días de su eliminación inicial.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de canciones eliminadas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('songs')
                  .where('groupId', isEqualTo: widget.group.id)
                  .where('isActive', isEqualTo: false)
                  .orderBy('deletedAt', descending: true)
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

                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay canciones eliminadas'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final deletedAt = song.deletedAt;
                    final daysLeft = 7 -
                        DateTime.now()
                            .difference(deletedAt ?? DateTime.now())
                            .inDays;

                    return Dismissible(
                      key: Key(song.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.green,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.restore,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Eliminar permanentemente
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar Permanentemente'),
                              content: Text(
                                  '¿Está seguro de eliminar permanentemente la canción "${song.title}"?\n\nEsta acción no se puede deshacer.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Restaurar
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Restaurar Canción'),
                              content: Text(
                                  '¿Desea restaurar la canción "${song.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Restaurar'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _deletePermanently(song);
                        } else {
                          await _restoreSong(song);
                        }
                      },
                      child: ListTile(
                        title: Text(song.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.author),
                            Text(
                              'Eliminada el ${DateFormat('dd/MM/yyyy').format(deletedAt ?? DateTime.now())}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            Text(
                              'Se eliminará permanentemente en $daysLeft días',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              onPressed: () => _restoreSong(song),
                              tooltip: 'Restaurar canción',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title:
                                        const Text('Eliminar Permanentemente'),
                                    content: Text(
                                        '¿Está seguro de eliminar permanentemente la canción "${song.title}"?\n\nEsta acción no se puede deshacer.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _deletePermanently(song);
                                }
                              },
                              tooltip: 'Eliminar permanentemente',
                            ),
                          ],
                        ),
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

  Future<void> _deletePermanently(SongModel song) async {
    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(song.id)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canción eliminada permanentemente'),
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

  Future<void> _restoreSong(SongModel song) async {
    try {
      await FirebaseFirestore.instance.collection('songs').doc(song.id).update({
        'isActive': true,
        'deletedAt': FieldValue.delete(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canción restaurada'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
