import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart'; // Importando las constantes
import 'song_detail_screen.dart'; // Importando la pantalla de detalles
import 'add_song_screen.dart'; // Importando la pantalla de agregar canción

class PersonalSongsScreen extends StatefulWidget {
  @override
  _PersonalSongsScreenState createState() => _PersonalSongsScreenState();
}

class _PersonalSongsScreenState extends State<PersonalSongsScreen> {
  String _searchQuery = ""; // Variable para almacenar la búsqueda
  String _sortOrder = 'asc'; // Orden por defecto: ascendente (A-Z)

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Mis Canciones", style: kTitleTextStyle),
        actions: [
          IconButton(
            icon: Icon(Icons.share, size: kIconSize, color: kIconColor),
            onPressed: () {
              // Funcionalidad de compartir
            },
          ),
          // Menú desplegable para elegir el orden
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                _sortOrder =
                    value; // Cambiar el orden de acuerdo a la selección
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
          // Botón de búsqueda
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
        stream: FirebaseFirestore.instance
            .collection('songs')
            .where('userId',
                isEqualTo: user?.uid) // Solo canciones del usuario logueado
            .orderBy('timestamp', descending: true) // Ordenar por timestamp
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No tienes canciones disponibles."));
          }

          final songs = snapshot.data!.docs;

          // Ordenar las canciones según el filtro seleccionado
          if (_sortOrder == 'asc') {
            songs.sort((a, b) {
              return (a['title'] ?? '').compareTo(b['title'] ?? '');
            });
          } else {
            songs.sort((a, b) {
              return (b['title'] ?? '').compareTo(a['title'] ?? '');
            });
          }

          final filteredSongs = songs.where((song) {
            final title = song['title']?.toLowerCase() ?? '';
            final author = song['author']?.toLowerCase() ?? '';
            final searchQueryLower = _searchQuery.toLowerCase();

            // Realiza la búsqueda de la subcadena en cualquier parte del título o autor
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

              return ListTile(
                title: Text(title),
                subtitle: Text('$author • Clave: $baseKey'),
                onTap: () {
                  // Navegar a la pantalla de detalles
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongDetailScreen(songId: song.id),
                    ),
                  );
                },
                trailing:
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegar a la pantalla de agregar canción
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSongScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('songs')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No se encontraron resultados."));
        }

        final songs = snapshot.data!.docs.where((song) {
          final title = song['title']?.toLowerCase() ?? '';
          final author = song['author']?.toLowerCase() ?? '';
          final searchQueryLower = query.toLowerCase();

          // Realiza la búsqueda de la subcadena en cualquier parte del título o autor
          return title.contains(searchQueryLower) ||
              author.contains(searchQueryLower);
        }).toList();

        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (ctx, index) {
            final song = songs[index];
            final title = song['title'] ?? 'Sin título';
            final author = song['author'] ?? 'Autor desconocido';
            final baseKey = song['baseKey'] ?? 'Clave no definida';

            return ListTile(
              title: Text(title),
              subtitle: Text('$author • Clave: $baseKey'),
              onTap: () {
                // Navegar a la pantalla de detalles
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongDetailScreen(songId: song.id),
                  ),
                );
              },
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
