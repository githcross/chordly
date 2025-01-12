import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        title: Text("Canciones eliminadas"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('songs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No hay canciones archivadas."));
          }

          final songs = snapshot.data!.docs;

          // Filtrar canciones según las reglas de acceso y estado archivado
          final archivedSongs = songs.where((doc) {
            final isOwner = doc['userId'] == user?.uid;
            final isArchived = doc['isArchived'] ?? false;
            final isPublic = doc['access'] == 'public';
            return isArchived && (isPublic || isOwner);
          }).toList();

          if (archivedSongs.isEmpty) {
            return Center(child: Text("No hay canciones eliminadas."));
          }

          return ListView.builder(
            itemCount: archivedSongs.length,
            itemBuilder: (ctx, index) {
              final song = archivedSongs[index];
              final title = song['title'] ?? 'Sin título';
              final author = song['author'] ?? 'Autor desconocido';
              final baseKey = song['baseKey'] ?? 'Clave no definida';

              return Dismissible(
                key: Key(song.id), // Identificador único para cada canción
                direction: DismissDirection.startToEnd,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Eliminar definitivamente',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) async {
                  try {
                    // Eliminar permanentemente la canción de Firestore
                    await FirebaseFirestore.instance
                        .collection('songs')
                        .doc(song.id)
                        .delete();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'La canción "$title" ha sido eliminada definitivamente.',
                        ),
                      ),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar: $error'),
                      ),
                    );
                  }
                },
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('$author • Clave: $baseKey'),
                  trailing: IconButton(
                    icon: Icon(Icons.unarchive, color: Colors.green),
                    tooltip: "Recuperar",
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('songs')
                            .doc(song.id)
                            .update({'isArchived': false});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'La canción "$title" se ha recuperado.',
                            ),
                          ),
                        );
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al recuperar: $error'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
