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

  String _selectedLanguage = 'English';

  // Function to save the song in Firestore
  void _saveSong() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text;
    final author = _authorController.text;
    final tags = _tagsController.text.split(',').map((e) => e.trim()).toList();
    final lyric = _lyricController.text;
    final timestamp = Timestamp.now();

    if (user != null &&
        title.isNotEmpty &&
        author.isNotEmpty &&
        lyric.isNotEmpty) {
      // Save the song in Firestore
      FirebaseFirestore.instance.collection('songs').add({
        'title': title,
        'author': author,
        'language': _selectedLanguage,
        'tags': tags,
        'lyric': lyric,
        'timestamp': timestamp,
        'userId': user.uid,
      });

      // Go back to the previous screen
      Navigator.pop(context);
    } else {
      // Show an error message
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('All fields are required')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Agregar Canción por Texto")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(labelText: 'Author'),
            ),
            DropdownButton<String>(
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
            ),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(labelText: 'Tags (comma separated)'),
            ),
            TextField(
              controller: _lyricController,
              decoration: InputDecoration(labelText: 'Lyric'),
              maxLines: 5,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSong,
              child: Text("Save Song"),
            ),
          ],
        ),
      ),
    );
  }
}
