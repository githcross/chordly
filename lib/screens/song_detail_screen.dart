import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart'; // Importando las constantes
import 'edit_song_screen.dart'; // Si tienes una pantalla de edición para la canción

class SongDetailScreen extends StatelessWidget {
  final String songId;

  SongDetailScreen({required this.songId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de la Canción", style: kTitleTextStyle),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: kIconColor),
            onPressed: () {
              // Navegar a la pantalla de edición
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSongScreen(songId: songId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('songs').doc(songId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("La canción no existe."));
          }

          final song = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Título: ${song['title']}", style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("Autor: ${song['author']}", style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("Idioma: ${song['language']}",
                      style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("Letra: ", style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("${song['lyric']}", style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("Etiquetas: ${song['tags'].join(', ')}",
                      style: kSubTitleTextStyle),
                  SizedBox(height: 8),
                  Text("Fecha de Creación: ${song['timestamp'].toDate()}",
                      style: kSubTitleTextStyle),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
