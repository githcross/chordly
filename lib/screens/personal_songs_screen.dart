import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/constants.dart';
import 'song_detail_screen.dart';
import 'add_song_screen.dart';
import 'archived_songs_screen.dart';

class PersonalSongsScreen extends StatefulWidget {
  @override
  _PersonalSongsScreenState createState() => _PersonalSongsScreenState();
}

class _PersonalSongsScreenState extends State<PersonalSongsScreen> {
  String _searchQuery = ""; // Variable para la búsqueda
  String _sortOrder = 'asc'; // Orden por defecto
  List<DocumentSnapshot> filteredSongs = []; // Lista de canciones filtradas

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Mis Canciones", style: kTitleTextStyle),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, size: kIconSize, color: kIconColor),
            tooltip: "Ver canciones archivadas", // Texto para accesibilidad
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ArchivedSongsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share, size: kIconSize, color: kIconColor),
            onPressed: () => _shareSongs(user),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                _sortOrder = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return ['asc', 'desc'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice == 'asc' ? 'Ordenar A-Z' : 'Ordenar Z-A'),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.search, size: kIconSize, color: kIconColor),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SongSearchDelegate(user: user),
              );
            },
          ),
        ],
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
            return Center(child: Text("No hay canciones disponibles."));
          }

          final songs = snapshot.data!.docs;

          // Filtrar canciones que son públicas o que pertenecen al usuario actual y no están archivadas
          final filtered = songs.where((doc) {
            final isPublic = doc['access'] == 'public';
            final isOwner = doc['userId'] == user?.uid;
            final isArchived = doc['isArchived'] ?? true; // Default to archived
            return (isPublic || isOwner) && !isArchived;
          }).toList();

          // Ordenar las canciones según el filtro seleccionado
          if (_sortOrder == 'asc') {
            filtered
                .sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
          } else {
            filtered
                .sort((a, b) => (b['title'] ?? '').compareTo(a['title'] ?? ''));
          }

          // Filtrar las canciones según el texto de búsqueda
          filteredSongs = filtered.where((song) {
            final title = song['title']?.toLowerCase() ?? '';
            final author = song['author']?.toLowerCase() ?? '';
            final searchQueryLower = _searchQuery.toLowerCase();
            return title.contains(searchQueryLower) ||
                author.contains(searchQueryLower);
          }).toList();

          return ListView.builder(
            itemCount: filteredSongs.length,
            itemBuilder: (ctx, index) {
              final song = filteredSongs[index];
              final title = song['title'] ?? 'Sin título';
              final author = song['author'] ?? 'Autor desconocido';
              final baseKey = song['baseKey'] ?? 'Clave no definida';

              return Dismissible(
                key: Key(song.id), // Identificador único para cada canción
                direction: DismissDirection
                    .startToEnd, // Deslizar de izquierda a derecha
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Eliminar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) async {
                  // Actualizar el campo isArchived en Firestore
                  try {
                    await FirebaseFirestore.instance
                        .collection('songs')
                        .doc(song.id)
                        .update({'isArchived': true});

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'La canción "$title" ha sido enviada a papelera de reciclaje,  puede recuperar en la sección papelera de reciclaje o se eliminará automaticamente en 24 horas.')),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Error al archivar la canción: $error')),
                    );
                  }
                },
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('$author • Clave: $baseKey'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailScreen(songId: song.id),
                      ),
                    );
                  },
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSongScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _shareSongs(User? user) {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, inicia sesión para compartir.')),
      );
      return;
    }

    final songTitles = List.generate(
      filteredSongs.length,
      (index) => filteredSongs[index]['title'] ?? 'Sin título',
    ).join('\n');

    final shareText = "Mis canciones:\n\n$songTitles";

    Share.share(shareText);
  }
}

class SongSearchDelegate extends SearchDelegate {
  final User? user;

  SongSearchDelegate({required this.user});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final searchQueryLower = query.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('songs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No se encontraron coincidencias."));
        }

        final songs = snapshot.data!.docs;

        final filteredSongs = songs.where((song) {
          final title = song['title']?.toLowerCase() ?? '';
          final author = song['author']?.toLowerCase() ?? '';
          return title.contains(searchQueryLower) ||
              author.contains(searchQueryLower);
        }).toList();

        return ListView.builder(
          itemCount: filteredSongs.length,
          itemBuilder: (ctx, index) {
            final song = filteredSongs[index];
            final title = song['title'] ?? 'Sin título';
            final author = song['author'] ?? 'Autor desconocido';

            return ListTile(
              title: Text(title),
              subtitle: Text('$author'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongDetailScreen(songId: song.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(child: Text("Busca por título o autor"));
  }
}
