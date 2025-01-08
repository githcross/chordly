import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PersonalSongsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mis Canciones"),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
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
