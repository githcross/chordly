// Archivo: lib/screens/edit_song_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class EditSongScreen extends StatefulWidget {
  final String songId;

  EditSongScreen({required this.songId});

  @override
  _EditSongScreenState createState() => _EditSongScreenState();
}

class _EditSongScreenState extends State<EditSongScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _lyricController;
  late TextEditingController _tagsController;
  late TextEditingController
      _baseKeyController; // Controlador para la clave base
  List<String> _tags = [];
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController();
    _lyricController = TextEditingController();
    _tagsController = TextEditingController();
    _baseKeyController = TextEditingController(); // Inicializar el controlador
    _fetchSongData();
  }

  // Recuperar los datos de la canción desde Firebase
  void _fetchSongData() async {
    DocumentSnapshot songDoc = await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get();
    if (songDoc.exists) {
      var song = songDoc.data() as Map<String, dynamic>;
      _titleController.text = song['title'];
      _authorController.text = song['author'];
      _lyricController.text = song['lyric'];
      _tags = List<String>.from(song['tags']);
      _tagsController.text = _tags.join(', ');
      _language = song['language'];
      _baseKeyController.text =
          song['baseKey'] ?? ''; // Recuperar la clave base
      setState(() {});
    }
  }

  // Guardar los cambios en Firebase
  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('songs').doc(widget.songId).update({
        'title': _titleController.text,
        'author': _authorController.text,
        'lyric': _lyricController.text,
        'tags': _tags,
        'language': _language,
        'baseKey': _baseKeyController.text, // Guardar la clave base
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Editar Canción"),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: kIconColor),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Título'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa un título';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _authorController,
                  decoration: InputDecoration(labelText: 'Autor'),
                ),
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(labelText: 'Etiquetas'),
                  onChanged: (value) {
                    _tags = value.split(',').map((e) => e.trim()).toList();
                  },
                ),
                TextFormField(
                  controller: _baseKeyController,
                  decoration: InputDecoration(labelText: 'Clave Base'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una clave base';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _language,
                  onChanged: (String? newValue) {
                    setState(() {
                      _language = newValue!;
                    });
                  },
                  items: <String>['English', 'Spanish']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: InputDecoration(labelText: 'Idioma'),
                ),
                SizedBox(height: 16),
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: TextFormField(
                    controller: _lyricController,
                    decoration: InputDecoration(labelText: 'Letra'),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
