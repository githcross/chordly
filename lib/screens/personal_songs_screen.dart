import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart'; // Importando las constantes
import 'song_detail_screen.dart'; // Importando la pantalla de detalles
import 'add_song_screen.dart'; // Importando la pantalla de agregar canción

class PersonalSongsScreen extends StatelessWidget {
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

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (ctx, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song['title']),
                subtitle: Text(song['author']),
                onTap: () {
                  // Navegar a la pantalla de detalles
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
