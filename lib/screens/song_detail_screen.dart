import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'teleprompter_screen.dart';
import '../utils/constants.dart';
import 'edit_song_screen.dart';

class SongDetailScreen extends StatefulWidget {
  final String songId;

  SongDetailScreen({required this.songId});

  @override
  _SongDetailScreenState createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late String lyrics;
  late DocumentSnapshot song;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles de la Canción",
            style:
                TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black.withOpacity(0.7)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSongScreen(songId: widget.songId),
                ),
              ).then((_) {
                refreshSongData();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward, color: Colors.blueAccent),
            onPressed: () {
              setState(() {
                lyrics = adjustNotes(lyrics, -1);
              });
              saveChangesToFirebase(lyrics);
            },
            iconSize: 30,
          ),
          IconButton(
            icon: Icon(Icons.arrow_upward, color: Colors.blueAccent),
            onPressed: () {
              setState(() {
                lyrics = adjustNotes(lyrics, 1);
              });
              saveChangesToFirebase(lyrics);
            },
            iconSize: 30,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.black.withOpacity(0.7)),
            onPressed: () {
              _generateAndSharePDF();
            },
          ),
          IconButton(
            icon:
                Icon(Icons.screen_share, color: Colors.black.withOpacity(0.7)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeleprompterScreen(lyrics: lyrics),
                ),
              );
            },
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

          song = snapshot.data!;
          lyrics = song['lyric'];

          // Cambiar expresión regular para encontrar notas dentro de ()
          final regex = RegExp(r'\(([A-Ga-g#b]+[mM]?)\)');
          final matches = regex.allMatches(lyrics);

          List<TextSpan> textSpans = [];
          int lastEnd = 0;

          for (final match in matches) {
            if (match.start > lastEnd) {
              textSpans.add(TextSpan(
                  text: lyrics.substring(lastEnd, match.start),
                  style: TextStyle(
                      color: Colors.black.withOpacity(0.8), fontSize: 16)));
            }

            textSpans.add(TextSpan(
              text: match.group(0),
              style: TextStyle(
                color: Colors.blueAccent,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
            ));

            lastEnd = match.end;
          }

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
                  Text("Clave Base: ${song['baseKey']}",
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

  void refreshSongData() {
    setState(() {});
  }

  void saveChangesToFirebase(String updatedLyrics) async {
    await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .update({
      'lyric': updatedLyrics,
    }).then((_) {
      print("Letra actualizada en Firebase");
    }).catchError((error) {
      print("Error al actualizar la letra: $error");
    });
  }

  String adjustNotes(String lyrics, int direction) {
    final regex = RegExp(r'\(([A-Ga-g#b]+[mM]?)\)');
    return lyrics.replaceAllMapped(regex, (match) {
      String chord = match.group(0)!;
      String chordName = match.group(1)!;

      String adjustedChord = shiftChord(chordName, direction);

      return chord.replaceFirst(chordName, adjustedChord);
    });
  }

  String shiftChord(String chord, int direction) {
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

    const minorChords = [
      'Cm',
      'C#m',
      'Dm',
      'D#m',
      'Em',
      'Fm',
      'F#m',
      'Gm',
      'G#m',
      'Am',
      'A#m',
      'Bm'
    ];

    // Si el acorde es menor, tratamos de ajustarlo
    if (minorChords.contains(chord)) {
      // Quitar el 'm' al final
      chord = chord.substring(0, chord.length - 1);
      String adjustedNote = shiftNote(chord, direction);
      return '$adjustedNote' + 'm'; // Reconstruir el acorde menor
    }

    // Si no es un acorde menor, simplemente ajustamos la nota como antes
    return shiftNote(chord, direction);
  }

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

    int index = notes.indexOf(note);
    if (index == -1) return note;

    int newIndex = (index + direction) % notes.length;
    if (newIndex < 0) newIndex += notes.length;

    return notes[newIndex];
  }

  void _generateAndSharePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Título: ${song['title']}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Autor: ${song['author']}',
                  style: pw.TextStyle(color: PdfColors.grey)),
              pw.Text('Idioma: ${song['language']}',
                  style: pw.TextStyle(color: PdfColors.grey)),
              pw.Text('Clave Base: ${song['baseKey']}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Letra:'),
              pw.SizedBox(height: 10),
              pw.Text('$lyrics'),
              pw.SizedBox(height: 10),
              pw.Text('Etiquetas: ${song['tags'].join(', ')}',
                  style: pw.TextStyle(color: PdfColors.grey)),
              pw.Text('Fecha de Creación: ${song['timestamp'].toDate()}',
                  style: pw.TextStyle(color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    final output = await pdf.save();
    await Printing.sharePdf(
        bytes: output, filename: 'cancion_${song['title']}.pdf');
  }
}
