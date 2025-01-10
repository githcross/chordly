// Archivo: lib/screens/song_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart'; // Importando las constantes
import 'edit_song_screen.dart'; // Si tienes una pantalla de edición para la canción

class SongDetailScreen extends StatefulWidget {
  final String songId;

  SongDetailScreen({required this.songId});

  @override
  _SongDetailScreenState createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late String lyrics; // Almacenará la letra de la canción

  // Variable para controlar el estado de la canción
  late DocumentSnapshot song;

  // Esta función se llama cuando volvemos de la pantalla de edición
  void refreshSongData() {
    setState(() {
      // Actualizamos los datos de la canción desde Firebase
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de la Canción",
            style:
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
        backgroundColor:
            Colors.transparent, // Fondo transparente para un aspecto limpio
        elevation: 0, // Elimina la sombra del AppBar
        actions: [
          // Icono de edición
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black.withOpacity(0.7)),
            onPressed: () {
              // Navegar a la pantalla de edición
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSongScreen(songId: widget.songId),
                ),
              ).then((_) {
                // Al regresar de la pantalla de edición, recargamos los datos
                refreshSongData();
              });
            },
          ),
          // Icono para bajar medio tono
          IconButton(
            icon: Icon(Icons.arrow_downward, color: Colors.blueAccent),
            onPressed: () {
              setState(() {
                lyrics = adjustNotes(lyrics, -1); // Bajar medio tono
              });
              saveChangesToFirebase(lyrics); // Guardar cambios en Firebase
            },
            iconSize: 30,
          ),
          // Icono para subir medio tono
          IconButton(
            icon: Icon(Icons.arrow_upward, color: Colors.blueAccent),
            onPressed: () {
              setState(() {
                lyrics = adjustNotes(lyrics, 1); // Subir medio tono
              });
              saveChangesToFirebase(lyrics); // Guardar cambios en Firebase
            },
            iconSize: 30,
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.songId)
            .get(),
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

          song = snapshot.data!; // Guardamos los datos de la canción
          lyrics = song['lyric']; // Almacenamos la letra de la canción

          // Usamos una expresión regular para encontrar las notas dentro de []
          final regex = RegExp(r'\[([A-Ga-g#b]+)\]');
          final matches = regex.allMatches(lyrics);

          // Creamos una lista de TextSpans
          List<TextSpan> textSpans = [];
          int lastEnd = 0;

          // Iteramos sobre las coincidencias y las agregamos a textSpans
          for (final match in matches) {
            // Agregar el texto anterior
            if (match.start > lastEnd) {
              textSpans.add(TextSpan(
                  text: lyrics.substring(lastEnd, match.start),
                  style: TextStyle(
                      color: Colors.black.withOpacity(0.8), fontSize: 16)));
            }

            // Agregar la nota musical con el estilo celeste
            textSpans.add(TextSpan(
              text: match.group(0),
              style: TextStyle(
                color: Colors.blueAccent, // Color relajante y moderno
                decoration: TextDecoration.underline, // Subrayado
                fontWeight: FontWeight.bold,
              ),
            ));

            lastEnd = match.end;
          }

          // Agregar el resto del texto después de la última coincidencia
          if (lastEnd < lyrics.length) {
            textSpans.add(TextSpan(
                text: lyrics.substring(lastEnd),
                style: TextStyle(
                    color: Colors.black.withOpacity(0.8), fontSize: 16)));
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Título: ${song['title']}",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text("Autor: ${song['author']}",
                      style: TextStyle(
                          fontSize: 16, color: Colors.black.withOpacity(0.7))),
                  SizedBox(height: 8),
                  Text("Idioma: ${song['language']}",
                      style: TextStyle(
                          fontSize: 16, color: Colors.black.withOpacity(0.7))),
                  SizedBox(height: 8),
                  Text(
                      "Clave Base: ${song['baseKey']}", // Mostrar la clave base
                      style: TextStyle(
                          fontSize: 16, color: Colors.black.withOpacity(0.7))),
                  SizedBox(height: 8),
                  Text("Letra: ",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: textSpans,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text("Etiquetas: ${song['tags'].join(', ')}",
                      style: TextStyle(
                          fontSize: 14, color: Colors.black.withOpacity(0.6))),
                  SizedBox(height: 8),
                  Text("Fecha de Creación: ${song['timestamp'].toDate()}",
                      style: TextStyle(
                          fontSize: 14, color: Colors.black.withOpacity(0.6))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Función para guardar los cambios en Firebase
  void saveChangesToFirebase(String updatedLyrics) async {
    await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({
      'lyric':
          updatedLyrics, // Actualizamos la letra con las nuevas notas ajustadas
    }).then((_) {
      print("Letra actualizada en Firebase");
    }).catchError((error) {
      print("Error al actualizar la letra: $error");
    });
  }

  // Función para ajustar las notas musicales
  String adjustNotes(String lyrics, int direction) {
    final regex = RegExp(
        r'\[([A-Ga-g#b]+)\]'); // Expresión regular para encontrar las notas dentro de []
    return lyrics.replaceAllMapped(regex, (match) {
      String note = match.group(0)!;
      String noteLetter = match.group(1)!;

      // Subir o bajar medio tono
      String adjustedNote = shiftNote(noteLetter, direction);

      // Reemplazar la nota ajustada en el texto original
      return note.replaceFirst(noteLetter, adjustedNote);
    });
  }

  // Función para cambiar medio tono de una nota
  String shiftNote(String note, int direction) {
    const notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];

    // Si la nota es con bemol, lo manejamos por separado
    if (note.length > 1 && note.endsWith('b')) {
      note = note.substring(0, note.length - 1); // Eliminar el 'b'
    }

    int index = notes.indexOf(note);
    if (index == -1) return note; // Si la nota no es válida

    int newIndex = (index + direction) % notes.length;
    if (newIndex < 0)
      newIndex += notes.length; // Asegurarse de que no se salga del rango

    // Reañadimos el 'b' (bemol) si la nota lo tenía
    return note.endsWith('b') ? '${notes[newIndex]}b' : notes[newIndex];
  }
}
