// Archivo: lib/screens/personal_songs_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/constants.dart'; // Importando las constantes

class PersonalSongsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mis Canciones", style: kTitleTextStyle),
        actions: [
          IconButton(
            icon: Icon(Icons.share, size: kIconSize, color: kIconColor),
            onPressed: () {
              Share.share(
                  '¡Revisa esta increíble lista de canciones que tengo en mi app!');
            },
          ),
        ],
      ),
      body: Center(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Aún no tienes canciones en tu lista. Usa el botón + para agregar nuevas canciones.",
                textAlign: TextAlign.center,
                style: kSubTitleTextStyle,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Agregar funcionalidad para añadir una nueva canción
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
