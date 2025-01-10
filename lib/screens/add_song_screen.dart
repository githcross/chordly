// Archivo: lib/screens/add_song_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSongScreen extends StatefulWidget {
  @override
  _AddSongScreenState createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _lyricController = TextEditingController();
  final TextEditingController _keyController =
      TextEditingController(); // Nuevo campo

  String _selectedLanguage = 'English';

  // Guardar la canción en Firestore
  void _saveSong() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final lyric = _lyricController.text.trim();
    final baseKey = _keyController.text.trim();
    final timestamp = Timestamp.now();

    if (user != null &&
        title.isNotEmpty &&
        author.isNotEmpty &&
        lyric.isNotEmpty &&
        baseKey.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('songs').add({
          'title': title,
          'author': author,
          'language': _selectedLanguage,
          'tags': tags,
          'lyric': lyric,
          'baseKey': baseKey,
          'timestamp': timestamp,
          'userId': user.uid,
        });
        Navigator.pop(context); // Regresar a la pantalla anterior
      } catch (e) {
        _showErrorSnackBar('Error al guardar la canción.');
      }
    } else {
      _showErrorSnackBar('Por favor, completa todos los campos.');
    }
  }

  // Mostrar mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Agregar Canción"),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Guardar',
            onPressed: _saveSong, // Llamar a la función para guardar la canción
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: 'Autor',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue!;
                });
              },
              items: <String>['English', 'Spanish']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: 'Idioma',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: 'Etiquetas (separadas por comas)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: 'Clave Base',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _lyricController,
              decoration: InputDecoration(
                labelText: 'Letra',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }
}
