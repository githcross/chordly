import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'song_detail_screen.dart';

class ArchivedSongsScreen extends StatefulWidget {
  @override
  _ArchivedSongsScreenState createState() => _ArchivedSongsScreenState();
}

class _ArchivedSongsScreenState extends State<ArchivedSongsScreen> {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Canciones Archivadas'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('songs')
            .where('isArchived', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final songs = snapshot.data?.docs ?? [];

          if (songs.isEmpty) {
            return Center(
              child: Text(
                'No hay canciones archivadas',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index].data() as Map<String, dynamic>;
              return Dismissible(
                key: Key(songs[index].id),
                direction: DismissDirection.startToEnd,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Eliminar permanentemente',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Confirmar eliminación'),
                        content: Text(
                            '¿Estás seguro de eliminar permanentemente esta canción?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  try {
                    final String songIdToDelete = songs[index].id;

                    // 1. Eliminar de la colección songs
                    await FirebaseFirestore.instance
                        .collection('songs')
                        .doc(songIdToDelete)
                        .delete();

                    // 2. Obtener todas las communities
                    final communitiesSnapshot = await FirebaseFirestore.instance
                        .collection('communities')
                        .get();

                    // 3. Revisar y actualizar cada community
                    for (var doc in communitiesSnapshot.docs) {
                      var communityData = doc.data();
                      if (communityData.containsKey('songs')) {
                        var songsList = List<Map<String, dynamic>>.from(
                            communityData['songs']);

                        // Verificar si la canción está en esta community
                        int initialLength = songsList.length;
                        songsList.removeWhere(
                            (song) => song['songId'] == songIdToDelete);
                        bool songWasRemoved = songsList.length < initialLength;

                        // Si se removió la canción, actualizar la community
                        if (songWasRemoved) {
                          await doc.reference.update({'songs': songsList});
                        }
                      }
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Canción eliminada permanentemente'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                        margin: EdgeInsets.only(
                          bottom: 20,
                          left: 16,
                          right: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Error al eliminar la canción: $e'),
                          ],
                        ),
                        margin: EdgeInsets.only(
                          bottom: 20,
                          left: 16,
                          right: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: ListTile(
                  leading: Icon(Icons.music_note),
                  title: Text(song['title'] ?? 'Sin título'),
                  subtitle: Text(song['author'] ?? 'Autor desconocido'),
                  trailing: IconButton(
                    icon: Icon(Icons.unarchive),
                    onPressed: () async {
                      try {
                        // Cambiar estado a no archivado y esperar a que se complete
                        await FirebaseFirestore.instance
                            .collection('songs')
                            .doc(songs[index].id)
                            .update({'isArchived': false});

                        // Mostrar mensaje después de que la actualización se complete
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Canción restaurada'),
                            duration: Duration(seconds: 2),
                            margin: EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al restaurar la canción: $e'),
                            margin: EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailScreen(
                          songId: songs[index].id,
                          isArchived: true,
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
    );
  }
}
